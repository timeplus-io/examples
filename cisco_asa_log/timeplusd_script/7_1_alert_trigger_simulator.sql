-- Simulate Critical Alert Logs from Cisco ASA Firewalls
CREATE RANDOM STREAM cisco_asa_simulator.cisco_asa_critical_logs (
    -- Timestamp
    timestamp datetime64(3) DEFAULT now64(3),
    
    -- Device identifier (asa-fw01 to asa-fw25)
    device_name string DEFAULT concat('asa-fw', lpad(to_string((rand(1) % 26) + 1), 2, '0')),
    
    -- Failover unit type
    unit_type string DEFAULT array_element(['Primary', 'Secondary'], (rand(2) % 2) + 1),
    
    -- Message category (all alerts)
    message_category string DEFAULT 'alert',
    
    -- Message ID list (ONLY severity 1 messages)
    message_id string DEFAULT array_element([
        -- ========== SEVERITY 1 - ALERT (Failover/HA) ==========
        '101001',  -- Failover cable OK
        '101002',  -- Bad failover cable
        '103002',  -- Other firewall network interface OK
        '104004',  -- Switching to OK
        '104500',  -- Switching to ACTIVE (cause)
        '104502',  -- Becoming Backup unit failed
        '105003',  -- Monitoring on interface waiting
        '105004',  -- Monitoring on interface normal
        '106022',  -- Deny TCP connection spoof
        '106101',  -- ACL log flows reached limit
        '107001'   -- RIP authentication failed
    ], (rand(5) % 11) + 1),
    
    -- Severity level (always 1 for this stream)
    severity int8 DEFAULT 1,
    
    -- Source IP addresses (realistic distribution)
    src_ip string DEFAULT multi_if(
        (rand(6) % 100) <= 60, concat('10.', to_string((rand(7) % 256)), '.', to_string((rand(8) % 256)), '.', to_string((rand(9) % 256))),
        (rand(10) % 100) <= 80, concat('192.168.', to_string((rand(11) % 256)), '.', to_string((rand(12) % 256))),
        (rand(13) % 100) <= 90, concat('172.', to_string((rand(14) % 16) + 16), '.', to_string((rand(15) % 256)), '.', to_string((rand(16) % 256))),
        concat(to_string((rand(17) % 223) + 1), '.', to_string((rand(18) % 256)), '.', to_string((rand(19) % 256)), '.', to_string((rand(20) % 256)))
    ),
    
    -- Destination IP addresses
    dst_ip string DEFAULT multi_if(
        (rand(21) % 100) <= 40, concat('10.', to_string((rand(22) % 256)), '.', to_string((rand(23) % 256)), '.', to_string((rand(24) % 256))),
        (rand(25) % 100) <= 55, concat('192.168.', to_string((rand(26) % 256)), '.', to_string((rand(27) % 256))),
        (rand(28) % 100) <= 65, concat('172.', to_string((rand(29) % 16) + 16), '.', to_string((rand(30) % 256)), '.', to_string((rand(31) % 256))),
        concat(to_string((rand(32) % 223) + 1), '.', to_string((rand(33) % 256)), '.', to_string((rand(34) % 256)), '.', to_string((rand(35) % 256)))
    ),
    
    -- Source port
    src_port uint16 DEFAULT multi_if(
        (rand(36) % 100) <= 70, (rand(37) % 30000) + 32768,
        (rand(38) % 65535) + 1
    ),
    
    -- Destination port (weighted towards services)
    dst_port uint16 DEFAULT multi_if(
        (rand(39) % 100) <= 30, 443,
        (rand(40) % 100) <= 50, 80,
        (rand(41) % 100) <= 65, 22,
        (rand(42) % 100) <= 75, 3389,
        (rand(43) % 100) <= 85, 53,
        (rand(44) % 100) <= 90, 25,
        (rand(45) % 65535) + 1
    ),
    
    -- Protocol
    protocol string DEFAULT array_element(['TCP', 'UDP', 'ICMP', 'ESP'], multi_if(
        (rand(46) % 100) <= 70, 1,
        (rand(47) % 100) <= 90, 2,
        (rand(48) % 100) <= 97, 3,
        4
    )),
    
    -- Interface names
    src_interface string DEFAULT array_element(['outside', 'inside', 'dmz', 'management', 'wan', 'lan', 'failover'], (rand(49) % 7) + 1),
    dst_interface string DEFAULT array_element(['outside', 'inside', 'dmz', 'management', 'wan', 'lan', 'failover'], (rand(50) % 7) + 1),
    
    -- Connection ID
    connection_id uint32 DEFAULT rand(51),
    
    -- TCP flags
    tcp_flags string DEFAULT array_element([
        'TCP FINs', 'TCP RSTs', 'TCP SYNs', 'TCP data', 'SYN ACK', 'FIN ACK'
    ], (rand(52) % 6) + 1),
    
    -- Connection direction
    direction string DEFAULT array_element(['Inbound', 'Outbound'], (rand(53) % 2) + 1),
    
    -- ACL name
    acl_name string DEFAULT array_element([
        'INSIDE_OUT', 'OUTSIDE_IN', 'DMZ_ACCESS', 'MANAGEMENT', 
        'VPN_ACCESS', 'DEFAULT_POLICY', 'INTERNET_ACCESS', 'ADMIN_ACL'
    ], (rand(54) % 8) + 1),
    
    -- Error code
    error_code string DEFAULT concat('0x', hex((rand(55) % 65535))),
    
    -- Failover reason
    failover_reason string DEFAULT array_element([
        'health check failed',
        'interface down',
        'manual switch',
        'configuration sync failed',
        'cable disconnect',
        'peer unreachable',
        'unit failure',
        'operator initiated'
    ], (rand(56) % 8) + 1),
    
    -- ACL flow limit
    acl_flow_limit uint32 DEFAULT (rand(57) % 5000) + 5000,
    
    -- RIP sequence
    rip_sequence uint32 DEFAULT rand(58) % 10000,
    
    -- Priority (syslog priority = facility * 8 + severity)
    -- Cisco ASA uses facility 23, so priority = 184 + 1 = 185
    priority uint8 DEFAULT 185,
    
    -- Message text construction based on message_id
    message_text string DEFAULT (
        multi_if(
            -- ========== SEVERITY 1 - FAILOVER MESSAGES ==========
            message_id = '101001', concat('(', unit_type, ') Failover cable OK.'),
            
            message_id = '101002', concat('(', unit_type, ') Bad failover cable.'),
            
            message_id = '103002', concat(
                '(', unit_type, ') Other firewall network interface ', src_interface, ' OK.'
            ),
            
            message_id = '104004', concat('(', unit_type, ') Switching to OK.'),
            
            message_id = '104500', concat(
                '(', unit_type, ') Switching to ACTIVE (cause: ', failover_reason, ')'
            ),
            
            message_id = '104502', concat('(', unit_type, ') Becoming Backup unit failed.'),
            
            message_id = '105003', concat(
                '(', unit_type, ') Monitoring on interface ', src_interface, ' waiting'
            ),
            
            message_id = '105004', concat(
                '(', unit_type, ') Monitoring on interface ', src_interface, ' normal'
            ),
            
            -- ========== SEVERITY 1 - SPOOFING/SECURITY ALERTS ==========
            message_id = '106022', concat(
                'Deny ', lower(protocol), ' connection spoof from ', src_ip, ' to ', dst_ip,
                ' on interface ', src_interface
            ),
            
            message_id = '106101', concat(
                'The number of ACL log flows has reached limit (', to_string(acl_flow_limit), ')'
            ),
            
            message_id = '107001', concat(
                'RIP auth failed from ', src_ip, ': version=2, type=md5, mode=', 
                array_element(['text', 'md5'], (rand(59) % 2) + 1), 
                ', sequence=', to_string(rip_sequence), ' on interface ', src_interface
            ),
            
            -- Default fallback
            concat('Alert event for message ID ', message_id, ' on device ', device_name)
        )
    ),
    
    -- Final log message in Cisco ASA syslog format
    log_message string DEFAULT concat(
        '<', to_string(priority), '>',
        format_datetime(timestamp, '%b %e %H:%M:%S'),
        ' ', device_name,
        ' %ASA-', to_string(severity), '-', message_id, ': ',
        message_text
    ),
    
    -- Additional flags for easy filtering
    is_failover_issue bool DEFAULT message_id IN (
        '101001', '101002', '103002', '104004', '104500', '104502', '105003', '105004'
    ),
    
    is_spoof_alert bool DEFAULT message_id = '106022',
    
    is_routing_issue bool DEFAULT message_id = '107001',
    
    is_acl_limit bool DEFAULT message_id = '106101'
    
) SETTINGS eps = 0.5;  -- 1 critical issue per two seconds

-- Materialized sending failover cable error logs
CREATE MATERIALIZED VIEW cisco_asa_simulator.mv_asa_critical_logs
INTO cisco_observability.asa_logs_stream 
AS
SELECT
    log_message AS message
FROM cisco_asa_simulator.cisco_asa_critical_logs;

SYSTEM PAUSE MATERIALIZED VIEW cisco_asa_simulator.mv_asa_critical_logs;
SYSTEM RESUME MATERIALIZED VIEW cisco_asa_simulator.mv_asa_critical_logs;


-- Simulate Brute Force Attack Logs (multiple failed AAA authentications)
CREATE RANDOM STREAM cisco_asa_simulator.brute_force_attack_stream(
    -- Timestamp
    timestamp datetime64(3) DEFAULT now64(3),
    
    -- Device identifier - multiple firewalls seeing the attack
    device_name string DEFAULT concat('asa-fw', lpad(to_string((rand(1) % 5) + 1), 2, '0')),
    
    -- Fixed message ID for authentication rejection
    message_id string DEFAULT '113015',
    
    -- Severity 4 - Warning (for 113015)
    severity int8 DEFAULT 4,
    
    -- Source IP addresses - Multiple attackers from different locations
    -- Simulate botnet/distributed attack with mix of public IPs
    src_ip string DEFAULT multi_if(
        (rand(2) % 100) <= 70, concat(to_string((rand(3) % 223) + 1), '.', to_string((rand(4) % 256)), '.', to_string((rand(5) % 256)), '.', to_string((rand(6) % 256))),
        (rand(7) % 100) <= 85, concat('185.', to_string((rand(8) % 256)), '.', to_string((rand(9) % 256)), '.', to_string((rand(10) % 256))),  -- Common attack ranges
        (rand(11) % 100) <= 95, concat('45.', to_string((rand(12) % 256)), '.', to_string((rand(13) % 256)), '.', to_string((rand(14) % 256))),   -- More attack ranges
        concat('198.', to_string((rand(15) % 256)), '.', to_string((rand(16) % 256)), '.', to_string((rand(17) % 256)))
    ),
    
    -- FIXED Destination IP - The target AAA server being attacked
    dst_ip string DEFAULT '10.50.100.25',  -- Single target server
    
    -- Source port - random high ports
    src_port uint16 DEFAULT (rand(18) % 30000) + 32768,
    
    -- Destination port - Common AAA/authentication ports
    dst_port uint16 DEFAULT array_element([
        1812,  -- RADIUS auth (most common)
        1645,  -- Old RADIUS auth
        49,    -- TACACS+
        389,   -- LDAP
        636,   -- LDAPS
        3389   -- RDP (if AAA server also hosts RDP)
    ], multi_if(
        (rand(19) % 100) <= 70, 1,  -- 70% RADIUS
        (rand(20) % 100) <= 85, 2,  -- 15% old RADIUS
        (rand(21) % 100) <= 92, 3,  -- 7% TACACS+
        (rand(22) % 100) <= 96, 4,  -- 4% LDAP
        (rand(23) % 100) <= 98, 5,  -- 2% LDAPS
        6                           -- 2% RDP
    )),
    
    -- Protocol
    protocol string DEFAULT 'UDP',  -- AAA typically uses UDP
    
    -- Interface names - attack coming from outside
    src_interface string DEFAULT 'outside',
    dst_interface string DEFAULT 'inside',
    
    -- Username - Common brute force username attempts
    username string DEFAULT array_element([
        'admin',
        'administrator',
        'root'
    ], (rand(24) % 30) + 1),
    
    -- AAA Server - The target server being attacked
    aaa_server string DEFAULT '10.50.100.25',  -- Same as dst_ip
    
    -- Authentication rejection reasons
    auth_reason string DEFAULT array_element([
        'Invalid password',
        'Invalid username',
        'Authentication timeout',
        'User not found',
        'Account locked',
        'Maximum retries exceeded',
        'Invalid credentials',
        'Access denied',
        'Authentication failed',
        'Login attempt blocked',
        'Password mismatch',
        'Unknown user'
    ], (rand(25) % 12) + 1),
    
    -- Action - always deny for failed auth
    action string DEFAULT 'deny',
    
    -- Priority (facility 20 - local4, severity 4 - warning)
    priority uint8 DEFAULT 164,
    
    -- Message text for 113015
    message_text string DEFAULT concat(
        'AAA user authentication Rejected: reason = ', auth_reason, 
        ': user = ', username, 
        ', server = ', aaa_server
    ),
    
    -- Final log message in Cisco ASA syslog format
    log_message string DEFAULT concat(
        '<', to_string(priority), '>',
        format_datetime(timestamp, '%b %e %H:%M:%S'),
        ' ', device_name,
        ' %ASA-', to_string(severity), '-', message_id, ': ',
        message_text
    )
) SETTINGS eps = 50;

CREATE MATERIALIZED VIEW cisco_asa_simulator.mv_brute_force_attack_logs
INTO cisco_observability.asa_logs_stream 
AS
SELECT
    log_message AS message
FROM cisco_asa_simulator.brute_force_attack_stream;

SYSTEM PAUSE MATERIALIZED VIEW cisco_asa_simulator.mv_brute_force_attack_logs;
SYSTEM RESUME MATERIALIZED VIEW cisco_asa_simulator.mv_brute_force_attack_logs;

--
CREATE RANDOM STREAM cisco_asa_simulator.ddos_attack (
    -- Timestamp
    timestamp datetime64(3) DEFAULT now64(3),
    
    -- Device identifier - firewall detecting the attack
    device_name string DEFAULT concat('asa-fw', lpad(to_string((rand(1) % 3) + 1), 2, '0')),
    
    -- Message ID - 90% TCP SYN flood (106015), 10% ICMP flood (313001)
    message_id string DEFAULT if((rand(2) % 100) <= 90, '106015', '313001'),
    
    -- Severity - both are warnings (4)
    severity int8 DEFAULT 4,
    
    -- Source IP addresses - Distributed attack from many different IPs (botnet)
    -- Simulate global botnet with diverse IP ranges
    src_ip string DEFAULT concat(
        to_string((rand(3) % 223) + 1), '.', 
        to_string((rand(4) % 256)), '.', 
        to_string((rand(5) % 256)), '.', 
        to_string((rand(6) % 256))
    ),
    
    -- FIXED Destination IP - Single target being attacked
    dst_ip string DEFAULT '192.168.10.100',  -- Web server or critical service being targeted
    
    -- Source port - Random high ports (ephemeral)
    src_port uint16 DEFAULT (rand(7) % 30000) + 32768,
    
    -- Destination port - Target service ports
    dst_port uint16 DEFAULT multi_if(
        message_id = '313001', 0,  -- ICMP doesn't use ports
        (rand(8) % 100) <= 60, 443,   -- 60% HTTPS
        (rand(9) % 100) <= 85, 80,    -- 25% HTTP
        (rand(10) % 100) <= 95, 22,   -- 10% SSH
        53                             -- 5% DNS
    ),
    
    -- Protocol
    protocol string DEFAULT if(message_id = '313001', 'ICMP', 'TCP'),
    
    -- Interface names - attack from outside
    src_interface string DEFAULT 'outside',
    dst_interface string DEFAULT 'dmz',  -- Target in DMZ
    
    -- Action - always deny (firewall blocking the flood)
    action string DEFAULT 'deny',
    
    -- Connection flags for TCP (SYN flood)
    tcp_flags string DEFAULT if(message_id = '106015', 'SYN', ''),
    
    -- ACL name that's blocking
    acl_name string DEFAULT 'outside_access_in',
    
    -- Priority (facility 20 - local4, severity 4 - warning)
    priority uint8 DEFAULT 164,
    
    -- Bytes (small packets in DDoS)
    bytes_sent uint32 DEFAULT if(message_id = '313001', rand(11) % 100, rand(12) % 500),
    
    -- Duration (very short - part of flood)
    duration uint16 DEFAULT rand(13) % 5,
    
    -- Message text based on message ID
    message_text string DEFAULT if(
        message_id = '106015',
        -- TCP SYN flood
        concat(
            'Deny TCP (no connection) from ', src_ip, '/', to_string(src_port),
            ' to ', dst_ip, '/', to_string(dst_port),
            ' flags ', tcp_flags,
            ' on interface ', src_interface
        ),
        -- ICMP flood  
        concat(
            'Denied ICMP type=', to_string((rand(14) % 2) + 8), ', code=0 from ',
            src_ip, ' on interface ', src_interface
        )
    ),
    
    -- Final log message in Cisco ASA syslog format
    log_message string DEFAULT concat(
        '<', to_string(priority), '>',
        format_datetime(timestamp, '%b %e %H:%M:%S'),
        ' ', device_name,
        ' %ASA-', to_string(severity), '-', message_id, ': ',
        message_text
    )
) SETTINGS eps = 500; 

CREATE MATERIALIZED VIEW cisco_asa_simulator.mv_ddos_attack_logs
INTO cisco_observability.asa_logs_stream 
AS
SELECT
    log_message AS message
FROM cisco_asa_simulator.ddos_attack;

SYSTEM PAUSE MATERIALIZED VIEW cisco_asa_simulator.mv_ddos_attack_logs;
SYSTEM RESUME MATERIALIZED VIEW cisco_asa_simulator.mv_ddos_attack_logs;