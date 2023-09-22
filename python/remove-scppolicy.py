import os
import json
import boto3
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

def lambda_handler(event, context):
    # Initialize the Boto3 client
    client = boto3.client('organizations')

    # Get the policy ID and target IDs from environment variables
    policy_id = os.environ.get('policy_id')
    target_ids = json.loads(os.environ.get('target_ids', '[]'))

    if not policy_id or not target_ids:
        return {
            'statusCode': 400,
            'body': json.dumps('Policy ID or Target IDs not found in environment variables')
        }

    for target_id in target_ids:
        try:
            # Attempt to remove the policy from the target
            response = client.detach_policy(
                PolicyId=policy_id,
                TargetId=target_id
            )
            print(f'Successfully detached policy {policy_id} from target {target_id}: {response}')
        except client.exceptions.PolicyNotAttachedException:
            print(f'Policy {policy_id} is not attached to target {target_id}')
        except (NoCredentialsError, PartialCredentialsError):
            return {
                'statusCode': 401,
                'body': json.dumps('AWS credentials not found')
            }
        except Exception as e:
            print(f'Failed to detach policy {policy_id} from target {target_id}: {str(e)}')

    return {
        'statusCode': 200,
        'body': json.dumps('Script executed successfully')
    }

if __name__ == '__main__':
    # For local testing, you can simulate an AWS Lambda environment with the following event and context
    event = {}
    context = {}
    print(lambda_handler(event, context))
