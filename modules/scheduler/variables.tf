variable "cluster_name" {
  description = "EKS cluster name — used in Lambda and EventBridge resource names"
  type        = string
}

variable "node_group_asg_names" {
  description = "Map of node-group key to ASG name (from modules/eks output)"
  type        = map(string)
}

variable "region" {
  description = "AWS region — passed to the Lambda as an environment variable for the SDK client"
  type        = string
  default     = "ap-southeast-3"
}

variable "start_min_size" {
  description = "ASG MinSize when starting the cluster"
  type        = number
  default     = 2
}

variable "start_desired_size" {
  description = "ASG DesiredCapacity when starting the cluster"
  type        = number
  default     = 2
}

variable "start_max_size" {
  description = "ASG MaxSize when starting the cluster"
  type        = number
  default     = 5
}

variable "enabled" {
  description = "Set to false to skip all scheduler resources"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to scheduler resources"
  type        = map(string)
  default     = {}
}
