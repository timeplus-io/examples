CREATE DATABASE IF NOT EXISTS cisco_o11y;

CREATE EXTERNAL STREAM IF NOT EXISTS cisco_o11y.asa_logs_stream (
    message string
)
SETTINGS type = 'kafka', brokers = 'redpanda:9092', topic = 'cisco_asa_logs', data_format='JSONEachRow', one_message_per_row=true;


-- Cisco ASA Log Grok Patterns - Corrected for Each Event ID

select
    grok(message,'<%{POSINT:priority}>%{SYSLOGTIMESTAMP:timestamp} %{HOSTNAME:device} %%{WORD:facility}-%{INT:severity}-%{INT:event_id}: %{GREEDYDATA:asa_message}') as m,
    
    -- Parse event-specific fields based on event_id
    multi_if(
        -- ============================================================
        -- 302013: Built TCP/UDP connection (HAS NAT IPs in parentheses)
        -- Format: Built {inbound|outbound} {TCP|UDP} connection ID for src_ifc:src_ip/src_port (nat_src_ip/nat_src_port) to dst_ifc:dst_ip/dst_port (nat_dst_ip/nat_dst_port)
        -- ============================================================
        m['event_id'] = '302013',
        grok(m['asa_message'],
             'Built %{DATA:direction} %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} \\(%{IP:nat_src_ip}/%{INT:nat_src_port}\\) to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} \\(%{IP:nat_dst_ip}/%{INT:nat_dst_port}\\)'),
        
        -- ============================================================
        -- 302014: Teardown TCP/UDP connection (NO NAT IPs, has duration/bytes/reason)
        -- Format: Teardown {TCP|UDP} connection ID for src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port duration H:MM:SS bytes ### reason
        -- ============================================================
        m['event_id'] = '302014',
        grok(m['asa_message'],
             'Teardown %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} duration %{DATA:duration} bytes %{INT:bytes} %{GREEDYDATA:reason}'),
        
        -- ============================================================
        -- 302015: Built UDP connection (similar to 302013)
        -- Format: Built {inbound|outbound} UDP connection ID for src_ifc:src_ip/src_port (nat_src_ip/nat_src_port) to dst_ifc:dst_ip/dst_port (nat_dst_ip/nat_dst_port)
        -- ============================================================
        m['event_id'] = '302015',
        grok(m['asa_message'],
             'Built %{DATA:direction} %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} \\(%{IP:nat_src_ip}/%{INT:nat_src_port}\\) to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} \\(%{IP:nat_dst_ip}/%{INT:nat_dst_port}\\)'),
        
        -- ============================================================
        -- 302016: Teardown UDP connection (similar to 302014 but no reason)
        -- Format: Teardown UDP connection ID for src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port duration H:MM:SS bytes ###
        -- ============================================================
        m['event_id'] = '302016',
        grok(m['asa_message'],
             'Teardown %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} duration %{DATA:duration} bytes %{INT:bytes}'),
        
        -- ============================================================
        -- 302020: Built ICMP connection
        -- Format: Built {inbound|outbound} ICMP connection for faddr dst_ip/0 gaddr nat_dst_ip/0 laddr src_ip/0
        -- ============================================================
        m['event_id'] = '302020',
        grok(m['asa_message'],
             'Built %{DATA:direction} ICMP connection for faddr %{IP:faddr}/0 gaddr %{IP:gaddr}/0 laddr %{IP:laddr}/0'),
        
        -- ============================================================
        -- 302021: Teardown ICMP connection
        -- Format: Teardown ICMP connection for faddr dst_ip/0 gaddr nat_dst_ip/0 laddr src_ip/0 duration H:MM:SS bytes ###
        -- ============================================================
        m['event_id'] = '302021',
        grok(m['asa_message'],
             'Teardown ICMP connection for faddr %{IP:faddr}/0 gaddr %{IP:gaddr}/0 laddr %{IP:laddr}/0 duration %{DATA:duration} bytes %{INT:bytes}'),
        
        -- ============================================================
        -- 305011: Built dynamic translation
        -- Format: Built dynamic {TCP|UDP|ICMP} translation from src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port
        -- NOTE: Uses "from...to" not "for...to"
        -- ============================================================
        m['event_id'] = '305011',
        grok(m['asa_message'],
             'Built dynamic %{DATA:protocol} translation from %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port}'),
        
        -- ============================================================
        -- 305012: Teardown dynamic translation
        -- Format: Teardown dynamic {TCP|UDP|ICMP} translation from src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port duration H:MM:SS
        -- NOTE: Uses "from...to" not "for...to"
        -- ============================================================
        m['event_id'] = '305012',
        grok(m['asa_message'],
             'Teardown dynamic %{DATA:protocol} translation from %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} duration %{DATA:duration}'),
        
        -- ============================================================
        -- 106023: Deny tcp/udp by ACL
        -- Format: Deny {tcp|udp} src src_ifc:src_ip/src_port dst dst_ifc:dst_ip/dst_port by access-group "ACL_NAME" [0x0, 0x0]
        -- ============================================================
        m['event_id'] = '106023',
        grok(m['asa_message'],
             'Deny %{DATA:protocol} src %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} dst %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} by access-group "%{DATA:acl_name}" \\[%{DATA:hex_codes}\\]'),
        
        -- ============================================================
        -- 106015: Deny TCP (no connection)
        -- Format: Deny {TCP|UDP} (no connection) from src_ip/src_port to dst_ip/dst_port flags {flags} on interface ifc_name
        -- ============================================================
        m['event_id'] = '106015',
        grok(m['asa_message'],
             'Deny %{DATA:protocol} \\(no connection\\) from %{IP:src_ip}/%{INT:src_port} to %{IP:dst_ip}/%{INT:dst_port} flags %{DATA:tcp_flags} on interface %{DATA:interface}'),
        
        -- ============================================================
        -- 106001: Deny reverse path check
        -- Format: Deny {tcp|udp|icmp} reverse path check from src_ip to dst_ip on interface ifc_name
        -- ============================================================
        m['event_id'] = '106001',
        grok(m['asa_message'],
             'Deny %{DATA:protocol} reverse path check from %{IP:src_ip} to %{IP:dst_ip} on interface %{DATA:interface}'),
        
        -- ============================================================
        -- 313001: Denied ICMP
        -- Format: Denied ICMP type=##, code=## from src_ip on interface ifc_name due to rate limit
        -- ============================================================
        m['event_id'] = '313001',
        grok(m['asa_message'],
             'Denied ICMP type=%{INT:icmp_type}, code=%{INT:icmp_code} from %{IP:src_ip} on interface %{DATA:interface}%{GREEDYDATA:reason}'),
        
        -- ============================================================
        -- 313004: Denied ICMP (no matching session)
        -- Format: Denied ICMP type=##, from laddr src_ip on interface ifc_name to dst_ip: no matching session
        -- ============================================================
        m['event_id'] = '313004',
        grok(m['asa_message'],
             'Denied ICMP type=%{INT:icmp_type}, from laddr %{IP:src_ip} on interface %{DATA:interface} to %{IP:dst_ip}: %{GREEDYDATA:reason}'),
        
        -- ============================================================
        -- 313005: No matching connection for ICMP error
        -- Format: No matching connection for ICMP error message: {details} on {interface} interface. Original IP payload: {details}
        -- ============================================================
        m['event_id'] = '313005',
        grok(m['asa_message'],
             'No matching connection for ICMP error message: %{GREEDYDATA:icmp_details}'),
        
        -- ============================================================
        -- 400013: IDS Alert
        -- Format: IDS:#### ICMP echo request from src_ip to dst_ip on interface ifc_name
        -- ============================================================
        m['event_id'] = '400013',
        grok(m['asa_message'],
             'IDS:%{INT:ids_signature} ICMP echo request from %{IP:src_ip} to %{IP:dst_ip} on interface %{DATA:interface}'),
        
        -- ============================================================
        -- 113004: AAA Authentication Successful
        -- Format: AAA user authentication Successful: server = server_ip, user = username
        -- ============================================================
        m['event_id'] = '113004',
        grok(m['asa_message'],
             'AAA user authentication Successful: server = %{IP:aaa_server}, user = %{DATA:username}'),
        
        -- ============================================================
        -- 113015: AAA Authentication Rejected
        -- Format: AAA user authentication Rejected: reason = {reason}: user = username, server = server_ip
        -- ============================================================
        m['event_id'] = '113015',
        grok(m['asa_message'],
             'AAA user authentication Rejected: reason = %{DATA:auth_reason}: user = %{DATA:username}, server = %{IP:aaa_server}'),
        
        -- ============================================================
        -- 713172: VPN IP Assignment
        -- Format: Group = vpn_group, IP = src_ip, Assigned private IP = private_ip
        -- ============================================================
        m['event_id'] = '713172',
        grok(m['asa_message'],
             'Group = %{DATA:vpn_group}, IP = %{IP:public_ip}, Assigned private IP = %{IP:private_ip}'),
        
        -- ============================================================
        -- Default: Return empty map for unparsed events
        -- ============================================================
        map_cast(['event_id'], [m['event_id']])
    ) as m1
    
from cisco_o11y.asa_logs_stream
where m['event_id'] in ['302013', '302014', '302015', '302016', '302020', '302021', 
                         '305011', '305012', '106023', '106015', '106001',
                         '313001', '313004', '313005', '400013', '113004', '113015', '713172']