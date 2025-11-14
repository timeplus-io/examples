CREATE DATABASE IF NOT EXISTS cisco_asa_simulator;

CREATE RANDOM STREAM cisco_asa_simulator.cisco_asa_logs (
    -- Timestamp
    timestamp datetime64(3) DEFAULT now64(3),
    
    -- Device identifier (asa-fw01 to asa-fw25)
    device_name string DEFAULT concat('asa-fw', lpad(to_string((rand(1) % 26) + 1), 2, '0')),
    
    -- Message category (for anomaly labeling)
    message_category string DEFAULT array_element([
        'informational',  -- 85% normal
        'warning',        -- 10% warnings
        'error',          -- 4% errors
        'anomalous'       -- 1% anomalies
    ], multi_if(
        (rand(2) % 100) <= 85, 1,
        (rand(3) % 100) <= 95, 2,
        (rand(4) % 100) <= 99, 3,
        4
    )),
    
    -- Message ID list (REMOVED only severity 1 messages)
    message_id string DEFAULT array_element([
        -- Informational messages (302xxx - Connection tracking)
        '302013', '302014', '302015', '302016', '302020', '302021',
        '302003', '302033', '302012',
        -- Informational (305xxx - State tracking)
        '305011', '305012',
        -- Informational (109xxx - Authentication)
        '109001', '109005', '109007',
        -- Informational (113xxx - AAA)
        '113004', '113015',
        -- Informational (212xxx - SNMP) - Severity 3
        '212003', '212004',
        -- Informational (303xxx - FTP)
        '303002',
        -- Informational (304xxx - URL)
        '304004',
        -- Informational (314xxx - RTSP)
        '314004',
        -- Informational (400xxx - IPS/IDS)
        '400013', '400038', '400043', '400044', '400048',
        -- Informational (502xxx - Group policy)
        '502111',
        -- Informational (713xxx - VPN)
        '713172',
        -- Informational (718xxx - Keepalive/Hello)
        '718012', '718015', '718019', '718021', '718023',
        -- Informational (710xxx - TCP access)
        '710002', '710003',
        -- Informational (318xxx - OSPF) - Severity 3
        '318107',
        
        -- Critical messages (106xxx - Deny/Access control) - Severity 2
        '106001',
        -- Warning messages (106xxx - Deny/Access control)
        '106015', '106023', '106100',
        -- Warning (313xxx - ICMP)
        '313001', '313004', '313005', '313008', '313009',
        -- Warning (304xxx - URL timeout) - Severity 3
        '304003',
        -- Warning (733xxx - Threat detection)
        '733102', '733104', '733105',
        -- Warning (750xxx - DoS protection)
        '750004',
        
        -- Critical (108xxx - SMTP threats) - Severity 2
        '108003',
        -- Error messages (202xxx - NAT exhaustion) - Severity 3
        '202010',
        -- Error (419xxx - VPN)
        '419002',
        -- Error (430xxx - VPN)
        '430002',
        
        -- NAT (602xxx, 702xxx)
        '602303', '602304', '702307'
    ], (rand(5) % 57) + 1),
    
    -- Severity level (auto-determined from message ID)
    -- NOW includes severity 2-7
    severity int8 DEFAULT multi_if(
        -- Severity 2 - Critical
        message_id IN ('106001', '108003'), 2,
        -- Severity 3 - Error  
        message_id IN ('212003', '212004', '304003', '313005', '318107', '202010', '313001'), 3,
        -- Severity 4 - Warning
        message_id IN ('106023', '106015', '113015', '313004', '400013', '400038', '400043', '400044', '400048', '733102', '733104', '733105'), 4,
        -- Severity 5 - Notification
        message_id IN ('502111', '718012', '718015', '750004'), 5,
        -- Severity 6 - Informational
        message_id IN ('109001', '109005', '109007', '113004', '302003', '302012', '302013', '302014', '302015', '302016', '302020', '302021', '302033', '304004', '305011', '305012', '313008', '313009', '314004', '602303', '602304', '702307', '419002', '430002', '713172'), 6,
        -- Severity 7 - Debug
        7
    ),
    
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
        (rand(36) % 100) <= 70, (rand(37) % 30000) + 32768,  -- Ephemeral ports
        (rand(38) % 65535) + 1
    ),
    
    -- Destination port (weighted towards services)
    dst_port uint16 DEFAULT multi_if(
        (rand(39) % 100) <= 30, 443,   -- HTTPS
        (rand(40) % 100) <= 50, 80,    -- HTTP
        (rand(41) % 100) <= 65, 22,    -- SSH
        (rand(42) % 100) <= 75, 3389,  -- RDP
        (rand(43) % 100) <= 85, 53,    -- DNS
        (rand(44) % 100) <= 90, 21,    -- FTP
        (rand(45) % 100) <= 93, 25,    -- SMTP
        (rand(46) % 100) <= 95, 3306,  -- MySQL
        (rand(47) % 100) <= 97, 5432,  -- PostgreSQL
        (rand(48) % 65535) + 1
    ),
    
    -- Protocol
    protocol string DEFAULT array_element(['TCP', 'UDP', 'ICMP', 'ESP', 'AH', 'GRE'], multi_if(
        (rand(49) % 100) <= 70, 1,  -- 70% TCP
        (rand(50) % 100) <= 90, 2,  -- 20% UDP
        (rand(51) % 100) <= 97, 3,  -- 7% ICMP
        (rand(52) % 3) + 4          -- 3% other
    )),
    
    -- Interface names
    src_interface string DEFAULT array_element(['outside', 'inside', 'dmz', 'management', 'wan', 'lan'], (rand(53) % 6) + 1),
    dst_interface string DEFAULT array_element(['outside', 'inside', 'dmz', 'management', 'wan', 'lan'], (rand(54) % 6) + 1),
    
    -- Connection ID (for session tracking)
    connection_id uint32 DEFAULT rand(55),
    
    -- Bytes transferred (realistic distribution)
    bytes_sent uint32 DEFAULT multi_if(
        protocol = 'ICMP', rand(56) % 1000,
        protocol = 'UDP', rand(57) % 50000,
        message_id IN ('302020', '302021'), rand(58) % 1000,  -- ICMP sessions
        rand(59) % 5000000  -- TCP can be large
    ),
    
    -- Username (authentication logs)
    username string DEFAULT concat(
        array_element(['admin', 'user', 'root', 'operator', 'guest', 'service', 'john', 'jane', 'bob', 'alice', 'system', 'test', 'vpn_user', 'webadmin'], (rand(60) % 14) + 1),
        multi_if((rand(61) % 100) <= 60, '', to_string((rand(62) % 100)))
    ),
    
    -- Action (permit/deny)
    action string DEFAULT multi_if(
        message_id IN ('106023', '106100', '313001', '313004', '313005'), 'deny',
        'permit'
    ),
    
    -- ACL name
    acl_name string DEFAULT array_element([
        'INSIDE_OUT', 'OUTSIDE_IN', 'DMZ_ACCESS', 'MANAGEMENT', 
        'VPN_ACCESS', 'DEFAULT_POLICY', 'INTERNET_ACCESS', 'ADMIN_ACL'
    ], (rand(63) % 8) + 1),
    
    -- NAT IPs
    nat_src_ip string DEFAULT multi_if(
        (rand(64) % 100) <= 50, src_ip,
        concat(to_string((rand(65) % 223) + 1), '.', to_string((rand(66) % 256)), '.', to_string((rand(67) % 256)), '.', to_string((rand(68) % 256)))
    ),
    
    nat_dst_ip string DEFAULT multi_if(
        (rand(69) % 100) <= 50, dst_ip,
        concat(to_string((rand(70) % 223) + 1), '.', to_string((rand(71) % 256)), '.', to_string((rand(72) % 256)), '.', to_string((rand(73) % 256)))
    ),
    
    -- Private VPN IP
    vpn_private_ip string DEFAULT concat('10.10.10.', to_string((rand(74) % 254) + 1)),
    
    -- VPN Group
    vpn_group string DEFAULT array_element(['vpn_user1', 'vpn_user2', 'remote_access', 'corporate_vpn'], (rand(75) % 4) + 1),
    
    -- AAA Server
    aaa_server string DEFAULT concat('10.0.0.', to_string((rand(76) % 50) + 1)),
    
    -- Auth reason
    auth_reason string DEFAULT array_element([
        'Invalid password', 'Account locked', 'User not found', 
        'Certificate expired', 'Authentication timeout'
    ], (rand(77) % 5) + 1),
    
    -- IDS signature
    ids_signature uint16 DEFAULT array_element([2004, 2001, 2005, 2010, 3002, 3005], (rand(78) % 6) + 1),
    
    -- ICMP type and code
    icmp_type uint8 DEFAULT (rand(79) % 18),
    icmp_code uint8 DEFAULT (rand(80) % 16),
    
    -- ICMP sequence number (for ICMP connection tracking)
    icmp_seq uint16 DEFAULT (rand(94) % 65536),
    
    -- RX ring number (for ICMP connection tracking)
    rx_ring_num uint8 DEFAULT (rand(95) % 8),
    
    -- Duration calculation helpers
    duration_seconds uint16 DEFAULT (rand(81) % 3600),
    
    -- Duration string (format: hh:mm:ss with leading zeros)
    duration string DEFAULT concat(
        lpad(to_string(floor(duration_seconds / 3600)), 2, '0'), ':',
        lpad(to_string(floor((duration_seconds % 3600) / 60)), 2, '0'), ':',
        lpad(to_string(duration_seconds % 60), 2, '0')
    ),
    
    -- TCP flags
    tcp_flags string DEFAULT array_element([
        'TCP FINs', 'TCP RSTs', 'TCP SYNs', 'TCP data'
    ], (rand(82) % 4) + 1),
    
    -- Connection direction
    direction string DEFAULT array_element(['Inbound', 'Outbound'], (rand(83) % 2) + 1),
    
    -- Filename (for FTP)
    filename string DEFAULT concat(
        array_element(['report', 'data', 'config', 'backup', 'log', 'document'], (rand(84) % 6) + 1),
        '.',
        array_element(['txt', 'pdf', 'zip', 'cfg', 'log', 'dat'], (rand(85) % 6) + 1)
    ),
    
    -- URL
    url string DEFAULT concat(
        'http://',
        array_element(['example', 'test', 'internal', 'web', 'site'], (rand(86) % 5) + 1),
        '.com/',
        array_element(['index', 'home', 'admin', 'api', 'data'], (rand(87) % 5) + 1),
        '.html'
    ),
    
    -- Error code
    error_code string DEFAULT concat('0x', hex((rand(88) % 65535))),
    
    -- Priority (syslog priority = facility * 8 + severity)
    -- Cisco ASA uses facility 23, so priority = 184 + severity (2-7)
    priority uint8 DEFAULT 184 + severity,
    
    -- Message text construction based on message_id
    message_text string DEFAULT (
        multi_if(
            -- ========== CONNECTION TRACKING (302xxx) ==========
            message_id = '302013', concat(
                'Built ', direction, ' ', upper(protocol), ' connection ', to_string(connection_id),
                ' for ', src_interface, ':', src_ip, '/', to_string(src_port),
                ' (', nat_src_ip, '/', to_string(src_port), ')',
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' (', nat_dst_ip, '/', to_string(dst_port), ')'
            ),
            
            message_id = '302014', concat(
                'Teardown ', upper(protocol), ' connection ', to_string(connection_id),
                ' for ', src_interface, ':', src_ip, '/', to_string(src_port),
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' duration ', duration, ' bytes ', to_string(bytes_sent), ' ', tcp_flags
            ),
            
            message_id = '302015', concat(
                'Built ', direction, ' ', upper(protocol), ' connection ', to_string(connection_id),
                ' for ', src_interface, ':', src_ip, '/', to_string(src_port),
                ' (', nat_src_ip, '/', to_string(src_port), ')',
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' (', nat_dst_ip, '/', to_string(dst_port), ')'
            ),
            
            message_id = '302016', concat(
                'Teardown ', upper(protocol), ' connection ', to_string(connection_id),
                ' for ', src_interface, ':', src_ip, '/', to_string(src_port),
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' duration ', duration, ' bytes ', to_string(bytes_sent)
            ),
            
            message_id = '302020', concat(
                'Built ', direction, ' ICMP connection for faddr ', dst_ip, '/', to_string(icmp_seq),
                ' gaddr ', nat_dst_ip, '/', to_string(icmp_seq),
                ' laddr ', src_ip, '/', to_string(icmp_seq)
            ),
            
            message_id = '302021', concat(
                'Teardown ICMP connection for faddr ', dst_ip, '/', to_string(icmp_seq),
                ' gaddr ', nat_dst_ip, '/', to_string(icmp_seq),
                ' laddr ', src_ip, '/', to_string(icmp_seq)
            ),
            
            message_id = '302003', concat(
                'Built ', direction, ' ', upper(protocol), ' connection for faddr ', dst_ip, '/', to_string(dst_port),
                ' gaddr ', nat_dst_ip, '/', to_string(dst_port), ' laddr ', src_ip, '/', to_string(src_port)
            ),
            
            message_id = '302033', concat(
                'Teardown ', upper(protocol), ' connection ', to_string(connection_id),
                ' from ', src_interface, ':', src_ip, '/', to_string(src_port),
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' duration ', duration, ' bytes ', to_string(bytes_sent), ' ', tcp_flags
            ),
            
            message_id = '302012', concat(
                'Teardown ', upper(protocol), ' connection ', to_string(connection_id),
                ' faddr ', dst_ip, '/', to_string(dst_port), ' gaddr ', nat_dst_ip, '/', to_string(dst_port),
                ' laddr ', src_ip, '/', to_string(src_port), ' duration ', duration, ' bytes ', to_string(bytes_sent)
            ),
            
            -- ========== ACCESS CONTROL (106xxx) ==========
            message_id = '106001', concat(
                direction, ' ', upper(protocol), ' connection denied from ', src_ip, '/', to_string(src_port),
                ' to ', dst_ip, '/', to_string(dst_port), ' flags ', tcp_flags, ' on interface ', src_interface
            ),
            
            message_id = '106015', concat(
                'Deny ', upper(protocol), ' (no connection) from ', src_ip, '/', to_string(src_port),
                ' to ', dst_ip, '/', to_string(dst_port), ' flags ', tcp_flags, ' on interface ', src_interface
            ),
            
            message_id = '106023', concat(
                'Deny ', lower(protocol), ' src ', src_interface, ':', src_ip, '/', to_string(src_port),
                ' dst ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' by access-group "', acl_name, '" [0x0, 0x0]'
            ),
            
            message_id = '106100', concat(
                'access-list "', acl_name, '" denied ', lower(protocol), ' ',
                src_interface, '/', src_ip, '(', to_string(src_port), ') -> ',
                dst_interface, '/', dst_ip, '(', to_string(dst_port), ') hit-cnt 1'
            ),
            
            -- ========== ICMP MESSAGES (313xxx) ==========
            message_id = '313001', concat(
                'Denied ICMP type=', to_string(icmp_type), ', code=', to_string(icmp_code),
                ' from ', src_ip, ' on interface ', src_interface
            ),
            
            message_id = '313004', concat(
                'Denied ICMP type=', to_string(icmp_type), ', from laddr ', src_ip,
                ' on interface ', src_interface, ' to ', dst_ip, ': no matching session'
            ),
            
            message_id = '313005', concat(
                'No matching connection for ICMP error message: ', 
                'icmp_type=', to_string(icmp_type), ' on ', src_interface, ' interface.'
            ),
            
            message_id = '313008', concat(
                'Denied ICMP type=', to_string(icmp_type), ', code=', to_string(icmp_code),
                ' from ', src_ip, ' on interface ', src_interface
            ),
            
            message_id = '313009', concat(
                'Denied invalid ICMP code ', to_string(icmp_code), ', for ', src_interface, ':', src_ip,
                '/', to_string(src_port), ' (', nat_src_ip, '/', to_string(src_port), ') to ',
                dst_interface, ':', dst_ip, '/', to_string(dst_port), ' (', nat_dst_ip, '/', to_string(dst_port), ')'
            ),
            
            -- ========== TRANSLATION (305xxx) ==========
            message_id = '305011', concat(
                'Built dynamic ', upper(protocol), ' translation from ',
                src_interface, ':', src_ip, '/', to_string(src_port),
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port)
            ),
            
            message_id = '305012', concat(
                'Teardown dynamic ', upper(protocol), ' translation from ',
                src_interface, ':', src_ip, '/', to_string(src_port),
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port),
                ' duration ', duration
            ),
            
            -- ========== AUTHENTICATION (109xxx) ==========
            message_id = '109001', concat(
                'Auth start for user ', username, ' from ', src_ip, '/', to_string(src_port), 
                ' to ', dst_ip, '/', to_string(dst_port)
            ),
            
            message_id = '109005', concat(
                'Authentication succeeded for user ', username, ' from ', src_ip, '/', to_string(src_port), 
                ' to ', dst_ip, '/', to_string(dst_port), ' on interface ', src_interface
            ),
            
            message_id = '109007', concat(
                'Authorization permitted for user ', username, ' from ', src_ip, '/', to_string(src_port), 
                ' to ', dst_ip, '/', to_string(dst_port), ' on interface ', src_interface
            ),
            
            -- ========== AAA (113xxx) ==========
            message_id = '113004', concat(
                'AAA user authentication Successful: server = ', aaa_server, ', user = ', username
            ),
            
            message_id = '113015', concat(
                'AAA user authentication Rejected: reason = ', auth_reason, ': user = ', username, ', server = ', aaa_server
            ),
            
            -- ========== VPN (713xxx) ==========
            message_id = '713172', concat(
                'Group = ', vpn_group, ', IP = ', src_ip, ', Assigned private IP = ', vpn_private_ip
            ),
            
            -- ========== SNMP (212xxx) ==========
            message_id = '212003', concat(
                'Unable to receive an SNMP request on interface ', src_interface, 
                ', error code = ', error_code, ', will try again'
            ),
            
            message_id = '212004', concat(
                'Unable to send an SNMP response to IP Address ', src_ip, 
                ' Port ', to_string(src_port), ' interface ', src_interface, 
                ', error code = ', error_code
            ),
            
            -- ========== FTP (303xxx) ==========
            message_id = '303002', concat(
                'FTP connection from ', src_interface, ':', src_ip, '/', to_string(src_port), 
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port), 
                ', user ', username, ' ', action, ' file ', filename
            ),
            
            -- ========== URL/WEB (304xxx, 314xxx) ==========
            message_id = '304003', concat('URL Server ', src_ip, ' timed out URL ', url),
            message_id = '304004', concat('URL Server ', src_ip, ' request failed URL ', url),
            message_id = '314004', concat('RTSP client ', src_interface, ':', src_ip, ' accessed RTSP URL ', url),
            
            -- ========== IPS/IDS (400xxx) ==========
            message_id = '400013', concat(
                'IDS:', to_string(ids_signature), ' ICMP echo request from ', src_ip, 
                ' to ', dst_ip, ' on interface ', src_interface
            ),
            
            message_id = '400038', concat(
                'IPS:6100 RPC Port Registration ', src_ip, ' to ', dst_ip, 
                ' on interface ', src_interface
            ),
            message_id = '400043', concat(
                'IPS:6151 ypbind (YP bind daemon) Portmap Request ', src_ip, ' to ', dst_ip, 
                ' on interface ', src_interface
            ),
            message_id = '400044', concat(
                'IPS:6152 yppasswdd (YP password daemon) Portmap Request ', src_ip, ' to ', dst_ip, 
                ' on interface ', src_interface
            ),
            message_id = '400048', concat(
                'IPS:6175 rexd (remote execution daemon) Portmap Request ', src_ip, ' to ', dst_ip, 
                ' on interface ', src_interface
            ),
            
            -- ========== GROUP POLICY (502xxx) ==========
            message_id = '502111', concat('New group policy added: name: ', acl_name, ' Type: external'),
            
            -- ========== TCP ACCESS (710xxx) ==========
            message_id = '710002', concat(
                'TCP access permitted from ', src_ip, '/', to_string(src_port), 
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port)
            ),
            
            message_id = '710003', concat(
                'TCP access denied by ACL from ', src_ip, '/', to_string(src_port), 
                ' to ', dst_interface, ':', dst_ip, '/', to_string(dst_port)
            ),
            
            -- ========== KEEPALIVE/HELLO (718xxx) ==========
            message_id = '718012', concat('Sent HELLO request to ', src_ip),
            message_id = '718015', concat('Received HELLO request from ', src_ip),
            message_id = '718019', concat('Sent KEEPALIVE request to ', src_ip),
            message_id = '718021', concat('Sent KEEPALIVE response to ', src_ip),
            message_id = '718023', concat('Received KEEPALIVE response from ', src_ip),
            
            -- ========== OSPF (318xxx) ==========
            message_id = '318107', concat('OSPF is enabled on ', src_interface, ' during configuration'),
            
            -- ========== THREAT DETECTION (733xxx) ==========
            message_id = '733102', concat('Threat-detection adds host ', src_ip, ' to shun list'),
            message_id = '733104', 'TD_SYSLOG_TCP_INTERCEPT_AVERAGE_RATE_EXCEED',
            message_id = '733105', 'TD_SYSLOG_TCP_INTERCEPT_BURST_RATE_EXCEED',
            
            -- ========== DOS PROTECTION (750xxx) ==========
            message_id = '750004', concat(
                'Local: ', src_ip, ':', to_string(src_port), 
                ' Remote: ', dst_ip, ':', to_string(dst_port), 
                ' Username: ', username, ' Sending COOKIE challenge to throttle possible DoS'
            ),
            
            -- ========== NAT (602xxx, 702xxx) ==========
            message_id = '602303', concat(
                'NAT: ', src_ip, '/', to_string(src_port), ' to ', 
                nat_src_ip, '/', to_string(src_port)
            ),
            message_id = '602304', concat(
                'NAT: ', dst_ip, '/', to_string(dst_port), ' to ', 
                nat_dst_ip, '/', to_string(dst_port)
            ),
            message_id = '702307', concat(
                'Dynamic NAT pool exhausted. Unable to create connection from ', 
                src_ip, '/', to_string(src_port), ' to ', dst_ip, '/', to_string(dst_port)
            ),
            
            -- ========== ERROR MESSAGES ==========
            message_id = '108003', concat(
                'Terminating ESMTP/SMTP connection; malicious pattern detected in the mail address from ',
                src_interface, ':', src_ip, '/', to_string(src_port), ' to ',
                dst_interface, ':', dst_ip, '/', to_string(dst_port), '. Data: ',
                array_element(['phishing attempt', 'malware detected', 'spam pattern', 'exploit code'], (rand(90) % 4) + 1)
            ),
            
            message_id = '202010', concat(
                'PAT pool exhausted. Unable to create ', protocol, ' connection from ', 
                src_ip, '/', to_string(src_port), ' to ', dst_ip, '/', to_string(dst_port)
            ),
            
            message_id = '419002', concat('VPN error: ', error_code),
            message_id = '430002', concat('VPN connection error from ', src_ip),
            
            -- Default fallback
            concat('Event for message ID ', message_id, ' from ', src_ip, ' to ', dst_ip)
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
) SETTINGS eps = 100;


CREATE EXTERNAL STREAM IF NOT EXISTS cisco_asa_simulator.asa_logs_stream (
    message string
)
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'cisco_asa_logs', data_format='JSONEachRow', one_message_per_row=true;


CREATE MATERIALIZED VIEW IF NOT EXISTS cisco_asa_simulator.mv_asa_logs
INTO cisco_asa_simulator.asa_logs_stream
AS
SELECT
    log_message AS message
FROM cisco_asa_simulator.cisco_asa_logs;