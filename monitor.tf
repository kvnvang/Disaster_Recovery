# SNS Topic for Alarm Notifications
resource "aws_sns_topic" "server_alerts" {
  name = "server-alerts-topic"
}

# SNS Topic Subscription for email
resource "aws_sns_topic_subscription" "email_alert" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.server_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# Route 53 Health Check
resource "aws_route53_health_check" "health_check" {
  provider          = aws.primary
  fqdn              = aws_instance.primary_instance.public_dns
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  request_interval  = "30"
  failure_threshold = 2
  regions           = ["us-east-1", "us-west-1", "us-west-2"]

  tags = {
    Name = "web-health-check"
  }
}

# CloudWatch Alarm to monitor health check
resource "aws_cloudwatch_metric_alarm" "web_alarm" {
  provider                = aws.primary
  alarm_name              = "health-availability-alarm"
  comparison_operator     = "GreaterThanOrEqualToThreshold"
  evaluation_periods      = 1
  metric_name             = "HealthyHostCount"
  namespace               = "AWS/Route53"
  period                  = 60
  statistic               = "Average"
  threshold               = 1
  alarm_description       = "Alarm monitors web app availability"
  alarm_actions           = [aws_sns_topic.server_alerts.arn]
  ok_actions              = [aws_sns_topic.server_alerts.arn]
  dimensions = {
    TargetGroup = aws_route53_health_check.health_check.id
  }
}

# AWS SSM Automation Document 
resource "aws_ssm_document" "dr_failover" {
  provider        = aws.primary
  name            = "DR-Failover-Automation"
  document_type   = "Automation"
  document_format = "YAML"

  content = <<DOC
    description = Automates DR failover to secondary region
    schemaVersion = '0.3'
    parameters:
     PrimaryRegion:
      type: String
      default: ${var.primary_region}
      description: Primary AWS region
     SecondaryRegion:
      type: String
      default: ${var.secondary_region}
      description: Secondary AWS region
     SecondaryInstanceId:
      type: String
      default: ${aws_instance.secondary_instance.id}
     PrimaryEndpointGroupARN:
      type: String
      default: ${aws_globalaccelerator_endpoint_group.primary_endpoint.arn}
     SecondaryEndpointGroupARN:
      type: String
      default: ${aws_globalaccelerator_endpoint_group.secondary_endpoint.arn}
    mainSteps:
     - name: StartSecondaryInstance
     action: aws:executeScript
     nextStep: WaitForSecondaryInstanceRunning
     isEnd: false
     inputs:
      Runtime: python3.11
      Handler: start_instance
      Script: |
       import boto3
       def start_instance(events, context):
        ec2 = boto3.client('ec2', region_name=events['SecondaryRegion'])
        response = ec2.start_instances(InstanceIds=[events['SecondaryInstanceId']])
        return {'InstanceState': response['StartingInstances'][0]['CurrentState']['Name']}
      InputPayload:
       SecondaryRegion: '{{ SecondaryRegion }}'
       SecondaryInstanceId: '{{ SecondaryInstanceId }}'
       - name: WaitForSecondaryInstanceRunning
    action: aws:executeScript
    nextStep: WaitForSecondaryInstanceStatusOk
    isEnd: false
    inputs:
      Runtime: python3.11
      Handler: wait_for_running
      Script: |
        import boto3
        import time

        def wait_for_running(events, context):
          ec2 = boto3.client('ec2', region_name=events['SecondaryRegion'])
          instance_id = events['SecondaryInstanceId']
          
          # Wait for instance to be in running state
          while True:
            response = ec2.describe_instances(InstanceIds=[instance_id])
            state = response['Reservations'][0]['Instances'][0]['State']['Name']
            
            if state == 'running':
              break
              
            time.sleep(10)
          
          return {'InstanceState': state}
      InputPayload:
        SecondaryRegion: '{{ SecondaryRegion }}'
        SecondaryInstanceId: '{{ SecondaryInstanceId }}'
  - name: WaitForSecondaryInstanceStatusOk
    action: aws:executeScript
    nextStep: UpdateTrafficDistribution
    isEnd: false
    inputs:
      Runtime: python3.11
      Handler: wait_for_status_ok
      Script: |
        import boto3
        import time

        def wait_for_status_ok(events, context):
          ec2 = boto3.client('ec2', region_name=events['SecondaryRegion'])
          instance_id = events['SecondaryInstanceId']
          
          # Wait for instance status checks to pass
          while True:
            try:
              response = ec2.describe_instance_status(InstanceIds=[instance_id])
              
              # If no status is returned yet, continue waiting
              if not response['InstanceStatuses']:
                time.sleep(15)
                continue
                
              instance_status = response['InstanceStatuses'][0]['InstanceStatus']['Status']
              system_status = response['InstanceStatuses'][0]['SystemStatus']['Status']
              
              if instance_status == 'ok' and system_status == 'ok':
                break
            except Exception as e:
              # Handle the case where status might not be available yet
              pass
              
            time.sleep(15)
          
          return {'InstanceStatus': 'ok'}
      InputPayload:
        SecondaryRegion: '{{ SecondaryRegion }}'
        SecondaryInstanceId: '{{ SecondaryInstanceId }}'
  - name: UpdateTrafficDistribution
    action: aws:executeScript
    nextStep: SendSuccessNotification
    isEnd: false
    inputs:
      Runtime: python3.11
      Handler: update_traffic
      Script: |
        import boto3

        def update_traffic(events, context):
          # Global Accelerator is a global service with no region in endpoint
          accelerator = boto3.client('globalaccelerator', region_name='us-west-2')
          
          # Get the endpoint ID - typically for EC2 this would be the instance ID
          # But sometimes it might be the ENI ID associated with the instance
          ec2 = boto3.client('ec2', region_name=events['SecondaryRegion'])
          instance_response = ec2.describe_instances(InstanceIds=[events['SecondaryInstanceId']])
          
          # Get the instance information
          instance = instance_response['Reservations'][0]['Instances'][0]
          
          # Update the endpoint group - use the ENI ID if available
          try:
            # Update the endpoint group with the correct endpoint ID
            # Note: For EC2 instances, the endpoint ID is typically the ENI ID
            network_interface_id = instance['NetworkInterfaces'][0]['NetworkInterfaceId']
            
            response = accelerator.update_endpoint_group(
              EndpointGroupArn=events['SecondaryEndpointGroupARN'],
              EndpointConfigurations=[
                {
                  'EndpointId': network_interface_id,
                  'Weight': 100,
                  'ClientIPPreservationEnabled': True
                }
              ]
            )
            return {'Status': 'Success', 'EndpointId': network_interface_id}
          except Exception as e:
            # Fall back to using the instance ID directly
            response = accelerator.update_endpoint_group(
              EndpointGroupArn=events['SecondaryEndpointGroupARN'],
              EndpointConfigurations=[
                {
                  'EndpointId': events['SecondaryInstanceId'],
                  'Weight': 100,
                  'ClientIPPreservationEnabled': True
                }
              ]
            )
            return {'Status': 'Success', 'EndpointId': events['SecondaryInstanceId']}
      InputPayload:
        SecondaryRegion: '{{ SecondaryRegion }}'
        SecondaryInstanceId: '{{ SecondaryInstanceId }}'
        SecondaryEndpointGroupARN: '{{ SecondaryEndpointGroupARN }}'
  - name: SendSuccessNotification
    action: aws:executeScript
    isEnd: true
    inputs:
      Runtime: python3.11
      Handler: send_notification
      Script: |
        import boto3

        def send_notification(events, context):
          sns = boto3.client('sns', region_name=events['PrimaryRegion'])
          
          response = sns.publish(
            TopicArn='${aws_sns_topic.server_alerts.arn}',
            Message='DR failover completed successfully. Traffic is now directed to the secondary instance.',
            Subject='DR Failover Complete'
          )
          
          return {'Status': 'Success'}
      InputPayload:
        PrimaryRegion: '{{ PrimaryRegion }}'
DOC
}