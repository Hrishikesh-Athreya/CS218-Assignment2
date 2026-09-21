import json
import os

import boto3


table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    employee_id = (event.get("pathParameters") or {}).get("id", "").strip()

    if not employee_id.isdigit():
        return response(400, {"message": "Invalid employee ID"})

    item = table.get_item(Key={"EmployeeID": employee_id}).get("Item")
    if not item:
        return response(404, {"message": "Employee not found"})

    return response(
        200,
        {
            "employeeId": item["EmployeeID"],
            "name": item["Name"],
            "salary": int(item["Salary"]),
            "dateOfJoin": item["DateOfJoin"],
            "description": item["Description"],
        },
    )

