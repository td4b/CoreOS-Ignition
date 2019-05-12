
variable "region" {
  default = "us-west-1"
}

provider "aws" {
  region = "${var.region}"
}

variable "bucket" {
  default = "labstatebucket"
}

variable "logbucket" {
  default = "lablogbucket"
}

# this can be changed to the IAM Role in the policy file.
variable "cannonicalid" {
  default = "d3d8d9782341148dcf75d3dcbb1c7cda2e485256abe59f7933e72f995be2159b"
}

data "template_file" "s3_public_policy" {
  template = "${file("s3policy.json")}"
  vars {
    canonicalId = "${var.cannonicalid}"
    bucket_name = "${var.bucket}"
  }
}

# Create Access Logging Bucket.
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.logbucket}"
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket" "s3_osquery" {
  bucket = "${var.bucket}"
  acl = "private"
  policy = "${data.template_file.s3_public_policy.rendered}"
  logging {
   target_bucket = "${aws_s3_bucket.log_bucket.id}"
   target_prefix = "log/"
 }
}

output "Logging_Bucket" {
  value = "${aws_s3_bucket.log_bucket.id}"
}
