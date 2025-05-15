

resource "google_compute_security_policy" "default" {
  count = var.enable_cloud_armor ? 1 : 0
  name  = "ca-${var.project_id}-${var.environment}-${var.unique_suffix}"

  # Rule to allow all traffic by default
  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule that allows all traffic"
  }


  # Rule to mitigate SQL injections
  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Rule to mitigate SQL injections"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  # Rule to mitigate XSS attacks
  rule {
    action      = "deny(403)"
    priority    = 1001
    description = "Rule to mitigate XSS attacks"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  # Rule to mitigate Remote Code Execution (RCE) attacks
  rule {
    action      = "deny(403)"
    priority    = 1002
    description = "Rule to mitigate Remote Code Execution (RCE) attacks"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('rce-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  #Rule to mitigate scanner detection attacks
  rule {
    action      = "deny(403)"
    priority    = 1003
    description = "Rule to mitigate scanner detection attacks"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('scannerdetection-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  #Rule to mitigate DoS attacks
  rule {
    action      = "rate_based_ban"
    priority    = 998
    description = "Rate limiting to prevent DDoS on authorized IPs"
    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = var.security_policy_ddos_ip_ranges_1
      }

    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = var.security_policy_ban_duration_sec
      rate_limit_threshold {
        count        = var.security_policy_rate_limit_count
        interval_sec = var.security_policy_rate_limit_interval
      }
    }
  }

  rule {
    action      = "rate_based_ban"
    priority    = 999
    description = "Rate limiting to prevent DDoS on authorized IPs"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.security_policy_ddos_ip_ranges_2
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = var.security_policy_ban_duration_sec
      rate_limit_threshold {
        count        = var.security_policy_rate_limit_count
        interval_sec = var.security_policy_rate_limit_interval
      }
    }
  }

  # Add JSON SQL Injection protection
  rule {
    action   = "deny(403)"
    priority = 1005
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('json-sqli-canary')"
      }
    }
    description = "Deny JSON SQL injection attempts"
  }

  # Add Local File Inclusion protection
  rule {
    action   = "deny(403)"
    priority = 1006
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('lfi-v33-stable')"
      }
    }
    description = "Deny LFI attacks"
  }

  # Add Remote File Inclusion protection
  rule {
    action   = "deny(403)"
    priority = 1007
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('rfi-v33-stable')"
      }
    }
    description = "Deny RFI attacks"
  }

  depends_on = [module.gke_autopilot]
}


