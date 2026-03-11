#!/usr/bin/env python3
"""
test.py — Automated integration test of the project
1. Programmatically authenticates with your us-east-1 Cognito pool to retrieve a JWT.
2. Injects the JWT as an authorization header and concurrently calls the /greet endpoint in both Region 1 and Region 2.
3. Concurrently calls the /dispatch endpoint in both Region 1 and Region 2 to trigger the ECS tasks.
4. Outputs the API responses to the console, specifically asserting that the payload region matches the requested region, 
alongside the measured latency for the requests to demonstrate the geographic performance difference.
"""

import argparse
import concurrent.futures
import json
import sys
import time

import boto3
import requests
from botocore.exceptions import ClientError


# Helpers

def authenticate(pool_id: str, client_id: str, email: str, password: str) -> str:
    """Returns an ID token JWT from Cognito USER_PASSWORD_AUTH flow."""
    client = boto3.client("cognito-idp", region_name="us-east-1")
    try:
        resp = client.initiate_auth(
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={"USERNAME": email, "PASSWORD": password},
            ClientId=client_id,
        )
        token = resp["AuthenticationResult"]["IdToken"]
        print(f"[AUTH] JWT obtained (pool: {pool_id})")
        return token
    except ClientError as e:
        print(f"[AUTH] Cognito error: {e.response['Error']['Message']}")
        sys.exit(1)


def call_endpoint(label: str, url: str, token: str) -> dict:
    """Makes a GET request with JWT header, returns timing + response body."""
    headers = {"Authorization": token}
    t0 = time.perf_counter()
    try:
        r = requests.get(url, headers=headers, timeout=30)
        latency_ms = (time.perf_counter() - t0) * 1000
        body = r.json()
        return {
            "label":      label,
            "status":     r.status_code,
            "latency_ms": round(latency_ms, 1),
            "body":       body,
            "ok":         r.status_code == 200,
        }
    except Exception as exc:  # noqa: BLE001
        latency_ms = (time.perf_counter() - t0) * 1000
        return {
            "label":      label,
            "status":     -1,
            "latency_ms": round(latency_ms, 1),
            "body":       {"error": str(exc)},
            "ok":         False,
        }


def assert_region(result: dict, expected_region: str) -> bool:
    region_in_body = result["body"].get("region", "")
    passed = region_in_body == expected_region
    status = "PASS" if passed else "FAIL"
    print(
        f"  [{result['label']}] {status}  "
        f"HTTP {result['status']}  "
        f"{result['latency_ms']} ms  "
        f"region={region_in_body!r} (expected {expected_region!r})"
    )
    return passed


# Main

def main():
    parser = argparse.ArgumentParser(description="Deployment to multi-region with lambda integration test")
    parser.add_argument("--pool-id",   required=True, help="Cognito User Pool ID (us-east-1_...)")
    parser.add_argument("--client-id", required=True, help="Cognito App Client ID")
    parser.add_argument("--email",     required=True, help="Test user email")
    parser.add_argument("--password",  required=True, help="Test user password")
    parser.add_argument("--api-us",    required=True, help="API Gateway base URL for us-east-1")
    parser.add_argument("--api-eu",    required=True, help="API Gateway base URL for eu-west-1")
    args = parser.parse_args()

    print("\nStep 1 — Cognito Authentication")
    token = authenticate(args.pool_id, args.client_id, args.email, args.password)

    # Step 2: concurrent /greet
    print("\nStep 2 — Concurrent /greet calls")
    greet_tasks = [
        ("greet/us-east-1", f"{args.api_us}/greet", "us-east-1"),
        ("greet/eu-west-1", f"{args.api_eu}/greet", "eu-west-1"),
    ]
    greet_results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = {
            pool.submit(call_endpoint, label, url, token): expected
            for label, url, expected in greet_tasks
        }
        for future, expected_region in futures.items():
            result = future.result()
            greet_results.append(assert_region(result, expected_region))
            print(f"    Body: {json.dumps(result['body'], indent=6)}")

    # Step 3: concurrent /dispatch
    print("\nStep 3 — Concurrent /dispatch calls (triggers ECS Fargate)")
    dispatch_tasks = [
        ("dispatch/us-east-1", f"{args.api_us}/dispatch", "us-east-1"),
        ("dispatch/eu-west-1", f"{args.api_eu}/dispatch", "eu-west-1"),
    ]
    dispatch_results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = {
            pool.submit(call_endpoint, label, url, token): expected
            for label, url, expected in dispatch_tasks
        }
        for future, expected_region in futures.items():
            result = future.result()
            dispatch_results.append(assert_region(result, expected_region))
            print(f"    Body: {json.dumps(result['body'], indent=6)}")

    # Summary
    all_passed = all(greet_results) and all(dispatch_results)
    print("\n=== Summary ===")
    print(f"  /greet assertions:    {'all passed' if all(greet_results) else 'some failed'}")
    print(f"  /dispatch assertions: {'all passed' if all(dispatch_results) else 'some failed'}")
    print(f"\n{'ALL TESTS PASSED' if all_passed else 'SOME TESTS FAILED'}")
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()