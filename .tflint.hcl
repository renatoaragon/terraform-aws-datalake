# tflint configuration. The built-in terraform ruleset needs no plugin
# download, so CI stays deterministic; the AWS ruleset can be added later.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
