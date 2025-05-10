

resource "google_compute_security_policy" "default" {
  name = "ca-${var.project_id}-${var.environment}-${var.unique_suffix}"

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
        src_ip_ranges = [
          "103.237.80.15/32",  # Bain APAC VPN
          "103.237.80.10/32",  # Bain APAC VPN
          "38.110.174.130/32", # Bain US-West VPN
          "58.220.95.0/24",    # ZScaler Ranges Start
          "94.188.131.0/25",   #
          "104.129.192.0/20",  #
          "128.177.125.0/24",  #
          "136.226.0.0/16",    #
          "137.83.128.0/18",   #
        "147.161.128.0/17", ]
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = 300
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
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
        src_ip_ranges = ["190.5.136.18/32", # Test LatAm 
          "154.113.23.0/24",                #
          "165.225.0.0/17",                 #
          "165.225.192.0/18",               #
          "185.46.212.0/22",                #
          "197.98.201.0/24",                #
          "211.144.19.0/24",                #
          "213.52.102.0/24",                # ZScaler Ranges End
        ]
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = 300
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
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


