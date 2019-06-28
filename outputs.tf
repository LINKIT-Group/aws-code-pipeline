
output "giturl_ssh" {
  value = "${aws_codecommit_repository.repository.clone_url_ssh}"
}
output "giturl_http" {
  value = "${aws_codecommit_repository.repository.clone_url_http}"
}
output "ecr_repository" {
  value = "${aws_ecr_repository.repository.repository_url}"
}
