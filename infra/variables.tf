variable "aws_region" {
  description = "AWS region for the application."
  type        = string
  default     = "us-west-2"
}

variable "cognito_domain_prefix" {
  description = "Globally unique prefix for the Cognito Managed Login domain."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.cognito_domain_prefix))
    error_message = "Use 1-63 lowercase letters, numbers, or hyphens."
  }
}

variable "student_name" {
  description = "Student name stored in the required employee record."
  type        = string
}

variable "student_aws_user_arn" {
  description = "IAM user ARN stored in the student employee Description."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:user/.+$", var.student_aws_user_arn))
    error_message = "Provide an IAM user ARN, not a root or role ARN."
  }
}

