-- Enhanced stream with enriched context and derived fields
CREATE STREAM cisco_o11y.flatten_extracted_asa_logs
(
  `ingestion_time` datetime64(3),
  `log_timestamp` string,
  `device_name` string,
  `severity` nullable(int8),
  `message_id` string,
  `asa_message` string,
  `asa_message_parsed` map(string, string),
  `direction` string,
  `protocol` string,
  `connection_id` nullable(uint64),
  `src_interface` string,
  `dst_interface` string,
  `src_ip` nullable(ipv4),
  `dst_ip` nullable(ipv4),
  `src_port` nullable(uint16),
  `dst_port` nullable(uint16),
  `nat_src_ip` nullable(ipv4),
  `nat_dst_ip` nullable(ipv4),
  `nat_src_port` nullable(uint16),
  `nat_dst_port` nullable(uint16),
  `faddr` nullable(ipv4),
  `gaddr` nullable(ipv4),
  `laddr` nullable(ipv4),
  `faddr_id` nullable(uint16),
  `gaddr_id` nullable(uint16),
  `laddr_id` nullable(uint16),
  `icmp_type` nullable(uint8),
  `icmp_code` nullable(uint8),
  `icmp_details` string,
  `duration` string,
  `bytes` nullable(uint64),
  `reason` string,
  `acl_name` string,
  `hex_codes` string,
  `tcp_flags` string,
  `interface` string,
  `ids_signature` nullable(uint32),
  `aaa_server` nullable(ipv4),
  `username` string,
  `auth_reason` string,
  `vpn_group` string,
  `public_ip` nullable(ipv4),
  `private_ip` nullable(ipv4)
)
TTL to_datetime(_tp_time) + INTERVAL 24 HOUR
SETTINGS index_granularity = 8192 , logstore_retention_bytes = '107374182', logstore_retention_ms = '300000';

CREATE VIEW cisco_o11y.v_parsed_asa_logs
AS
SELECT
    *,
    -- Parse event-specific fields based on event_id
    multi_if(
        -- ============================================================
        -- 302013: Built TCP/UDP connection (HAS NAT IPs in parentheses)
        -- Format: Built {inbound|outbound} {TCP|UDP} connection ID for src_ifc:src_ip/src_port (nat_src_ip/nat_src_port) to dst_ifc:dst_ip/dst_port (nat_dst_ip/nat_dst_port)
        -- ============================================================
        message_id = '302013',
        grok(asa_message,
             'Built %{DATA:direction} %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} \\(%{IP:nat_src_ip}/%{INT:nat_src_port}\\) to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} \\(%{IP:nat_dst_ip}/%{INT:nat_dst_port}\\)'),
        
        -- ============================================================
        -- 302014: Teardown TCP/UDP connection (NO NAT IPs, has duration/bytes/reason)
        -- Format: Teardown {TCP|UDP} connection ID for src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port duration H:MM:SS bytes ### reason
        -- ============================================================
        message_id = '302014',
        grok(asa_message,
             'Teardown %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} duration %{DATA:duration} bytes %{INT:bytes} %{GREEDYDATA:reason}'),
        
        -- ============================================================
        -- 302015: Built UDP connection (similar to 302013)
        -- Format: Built {inbound|outbound} UDP connection ID for src_ifc:src_ip/src_port (nat_src_ip/nat_src_port) to dst_ifc:dst_ip/dst_port (nat_dst_ip/nat_dst_port)
        -- ============================================================
        message_id = '302015',
        grok(asa_message,
             'Built %{DATA:direction} %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} \\(%{IP:nat_src_ip}/%{INT:nat_src_port}\\) to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} \\(%{IP:nat_dst_ip}/%{INT:nat_dst_port}\\)'),
        
        -- ============================================================
        -- 302016: Teardown UDP connection (similar to 302014 but no reason)
        -- Format: Teardown UDP connection ID for src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port duration H:MM:SS bytes ###
        -- ============================================================
        message_id = '302016',
        grok(asa_message,
             'Teardown %{DATA:protocol} connection %{INT:connection_id} for %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} duration %{DATA:duration} bytes %{INT:bytes}.*'),
        
        -- ============================================================
        -- 302020: Built ICMP connection
        -- Format: Built {inbound|outbound} ICMP connection for faddr dst_ip/0 gaddr nat_dst_ip/0 laddr src_ip/0
        -- ============================================================
        message_id = '302020',
        grok(asa_message,
             'Built %{DATA:direction} ICMP connection for faddr %{IP:faddr}/%{INT:faddr_id} gaddr %{IP:gaddr}/%{INT:gaddr_id} laddr %{IP:laddr}/%{INT:laddr_id}'),
        
        -- ============================================================
        -- 302021: Teardown ICMP connection
        -- Format: Teardown ICMP connection for faddr dst_ip/0 gaddr nat_dst_ip/0 laddr src_ip/0 duration H:MM:SS bytes ###
        -- ============================================================
        message_id = '302021',
        grok(asa_message,
             'Teardown ICMP connection for faddr %{IP:faddr}/%{INT:faddr_id} gaddr %{IP:gaddr}/%{INT:gaddr_id} laddr %{IP:laddr}/%{INT:laddr_id}( duration %{DATA:duration})?( bytes %{INT:bytes})?'),
        
        -- ============================================================
        -- 305011: Built dynamic translation
        -- Format: Built dynamic {TCP|UDP|ICMP} translation from src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port
        -- NOTE: Uses "from...to" not "for...to"
        -- ============================================================
        message_id = '305011',
        grok(asa_message,
             'Built dynamic %{DATA:protocol} translation from %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port}'),
        
        -- ============================================================
        -- 305012: Teardown dynamic translation
        -- Format: Teardown dynamic {TCP|UDP|ICMP} translation from src_ifc:src_ip/src_port to dst_ifc:dst_ip/dst_port duration H:MM:SS
        -- NOTE: Uses "from...to" not "for...to"
        -- ============================================================
        message_id = '305012',
        grok(asa_message,
             'Teardown dynamic %{DATA:protocol} translation from %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} to %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} duration %{DATA:duration}'),
        
        -- ============================================================
        -- 106023: Deny tcp/udp by ACL
        -- Format: Deny {tcp|udp} src src_ifc:src_ip/src_port dst dst_ifc:dst_ip/dst_port by access-group "ACL_NAME" [0x0, 0x0]
        -- ============================================================
        message_id = '106023',
        grok(asa_message,
             'Deny %{DATA:protocol} src %{DATA:src_interface}:%{IP:src_ip}/%{INT:src_port} dst %{DATA:dst_interface}:%{IP:dst_ip}/%{INT:dst_port} by access-group "%{DATA:acl_name}" \\[%{DATA:hex_codes}\\]'),
        
        -- ============================================================
        -- 106015: Deny TCP (no connection)
        -- Format: Deny {TCP|UDP} (no connection) from src_ip/src_port to dst_ip/dst_port flags {flags} on interface ifc_name
        -- ============================================================
        message_id = '106015',
        grok(asa_message,
             'Deny %{DATA:protocol} \\(no connection\\) from %{IP:src_ip}/%{INT:src_port} to %{IP:dst_ip}/%{INT:dst_port} flags %{DATA:tcp_flags} on interface %{DATA:interface}'),
        
        -- ============================================================
        -- 313001: Denied ICMP
        -- Format: Denied ICMP type=##, code=## from src_ip on interface ifc_name due to rate limit
        -- ============================================================
        message_id = '313001',
        grok(asa_message,
             'Denied ICMP type=%{INT:icmp_type}, code=%{INT:icmp_code} from %{IP:src_ip} on interface %{DATA:interface}%{GREEDYDATA:reason}'),
        
        -- ============================================================
        -- 313004: Denied ICMP (no matching session)
        -- Format: Denied ICMP type=##, from laddr src_ip on interface ifc_name to dst_ip: no matching session
        -- ============================================================
        message_id = '313004',
        grok(asa_message,
             'Denied ICMP type=%{INT:icmp_type}, from laddr %{IP:src_ip} on interface %{DATA:interface} to %{IP:dst_ip}: %{GREEDYDATA:reason}'),
        
        -- ============================================================
        -- 313005: No matching connection for ICMP error
        -- Format: No matching connection for ICMP error message: {details} on {interface} interface. Original IP payload: {details}
        -- ============================================================
        message_id = '313005',
        grok(asa_message,
             'No matching connection for ICMP error message: %{GREEDYDATA:icmp_details}'),
        
        -- ============================================================
        -- 400013: IDS Alert
        -- Format: IDS:#### ICMP echo request from src_ip to dst_ip on interface ifc_name
        -- ============================================================
        message_id = '400013',
        grok(asa_message,
             'IDS:%{INT:ids_signature} ICMP echo request from %{IP:src_ip} to %{IP:dst_ip} on interface %{DATA:interface}'),
        
        -- ============================================================
        -- 113004: AAA Authentication Successful
        -- Format: AAA user authentication Successful: server = server_ip, user = username
        -- ============================================================
        message_id = '113004',
        grok(asa_message,
             'AAA user authentication Successful: server = %{IP:aaa_server}, user = %{DATA:username}'),
        
        -- ============================================================
        -- 113015: AAA Authentication Rejected
        -- Format: AAA user authentication Rejected: reason = {reason}: user = username, server = server_ip
        -- ============================================================
        message_id = '113015',
        grok(asa_message,
             'AAA user authentication Rejected: reason = %{DATA:auth_reason}: user = %{DATA:username}, server = %{IP:aaa_server}'),
        
        -- ============================================================
        -- 713172: VPN IP Assignment
        -- Format: Group = vpn_group, IP = src_ip, Assigned private IP = private_ip
        -- ============================================================
        message_id = '713172',
        grok(asa_message,
             'Group = %{DATA:vpn_group}, IP = %{IP:public_ip}, Assigned private IP = %{IP:private_ip}'),
        
        -- ============================================================
        -- Default: Return empty map for unparsed events
        -- ============================================================
        map_cast(['message_id'], [message_id])
    ) as asa_message_parsed
FROM cisco_o11y.parsed_asa_logs;

CREATE VIEW cisco_o11y.v_flatten_asa_logs
AS
SELECT
    -- Original fields
    *,
    -- Flatten map fields with type casting
    -- Common Connection Fields
    asa_message_parsed['direction'] as direction,
    asa_message_parsed['protocol'] as protocol,
    to_uint64_or_null(asa_message_parsed['connection_id']) as connection_id,
    asa_message_parsed['src_interface'] as src_interface,
    asa_message_parsed['dst_interface'] as dst_interface,
    to_ipv4_or_null(asa_message_parsed['src_ip']) as src_ip,
    to_ipv4_or_null(asa_message_parsed['dst_ip']) as dst_ip,
    to_uint16_or_null(asa_message_parsed['src_port']) as src_port,
    to_uint16_or_null(asa_message_parsed['dst_port']) as dst_port,
    
    -- NAT Fields
    to_ipv4_or_null(asa_message_parsed['nat_src_ip']) as nat_src_ip,
    to_ipv4_or_null(asa_message_parsed['nat_dst_ip']) as nat_dst_ip,
    to_uint16_or_null(asa_message_parsed['nat_src_port']) as nat_src_port,
    to_uint16_or_null(asa_message_parsed['nat_dst_port']) as nat_dst_port,
    
    -- ICMP Fields
    to_ipv4_or_null(asa_message_parsed['faddr']) as faddr,
    to_ipv4_or_null(asa_message_parsed['gaddr']) as gaddr,
    to_ipv4_or_null(asa_message_parsed['laddr']) as laddr,
    to_uint16_or_null(asa_message_parsed['faddr_id']) as faddr_id,
    to_uint16_or_null(asa_message_parsed['gaddr_id']) as gaddr_id,
    to_uint16_or_null(asa_message_parsed['laddr_id']) as laddr_id,
    to_uint8_or_null(asa_message_parsed['icmp_type']) as icmp_type,
    to_uint8_or_null(asa_message_parsed['icmp_code']) as icmp_code,
    asa_message_parsed['icmp_details'] as icmp_details,
    
    -- Traffic Metrics
    asa_message_parsed['duration'] as duration,
    to_uint64_or_null(asa_message_parsed['bytes']) as bytes,
    asa_message_parsed['reason'] as reason,
    
    -- Security/ACL
    asa_message_parsed['acl_name'] as acl_name,
    asa_message_parsed['hex_codes'] as hex_codes,
    asa_message_parsed['tcp_flags'] as tcp_flags,
    asa_message_parsed['interface'] as interface,
    
    -- IDS/Authentication
    to_uint32_or_null(asa_message_parsed['ids_signature']) as ids_signature,
    to_ipv4_or_null(asa_message_parsed['aaa_server']) as aaa_server,
    asa_message_parsed['username'] as username,
    asa_message_parsed['auth_reason'] as auth_reason,
    
    -- VPN
    asa_message_parsed['vpn_group'] as vpn_group,
    to_ipv4_or_null(asa_message_parsed['public_ip']) as public_ip,
    to_ipv4_or_null(asa_message_parsed['private_ip']) as private_ip
FROM cisco_o11y.v_parsed_asa_logs;

CREATE MATERIALIZED VIEW cisco_o11y.mv_enhanced_asa_logs
INTO cisco_o11y.flatten_extracted_asa_logs AS
SELECT
    *
FROM cisco_o11y.v_flatten_asa_logs;

-- Mutable stream for device/asset information
CREATE MUTABLE STREAM cisco_o11y.device_assets
(
  `device_name` string,
  `hostname` string,
  `location` string,
  `datacenter` string,
  `rack_position` string,
  `device_type` string,
  `hardware_model` string,
  `software_version` string,
  `management_ip` string,
  `owner_team` string,
  `criticality` string,
  `deployment_date` datetime,
  `maintenance_window` string,
  `last_updated` datetime64(3) DEFAULT now64(3)
)
PRIMARY KEY device_name;

-- Insert sample device data
-- Insert device assets for FW00 to FW30
INSERT INTO cisco_o11y.device_assets (device_name, hostname, location, datacenter, rack_position, device_type, hardware_model, software_version, management_ip, owner_team, criticality, deployment_date, maintenance_window) VALUES
('FW00', 'fw-dc1-edge-01', 'US-East', 'DC1-NewYork', 'R12-U15', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.10.1.10', 'Network-Security', 'Critical', '2022-01-15', 'Sun 02:00-06:00'),
('FW01', 'fw-dc1-edge-02', 'US-East', 'DC1-NewYork', 'R12-U16', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.10.1.11', 'Network-Security', 'Critical', '2022-01-15', 'Sun 02:00-06:00'),
('FW02', 'fw-dc1-dmz-01', 'US-East', 'DC1-NewYork', 'R15-U10', 'DMZ Firewall', 'ASA-5545-X', '9.16.2', '10.10.2.10', 'Network-Security', 'High', '2021-08-20', 'Sat 22:00-02:00'),
('FW03', 'fw-dc1-dmz-02', 'US-East', 'DC1-NewYork', 'R15-U11', 'DMZ Firewall', 'ASA-5545-X', '9.16.2', '10.10.2.11', 'Network-Security', 'High', '2021-08-20', 'Sat 22:00-02:00'),
('FW04', 'fw-dc1-internal-01', 'US-East', 'DC1-NewYork', 'R18-U05', 'Internal Firewall', 'ASA-5525-X', '9.14.3', '10.10.3.10', 'Network-Security', 'Medium', '2020-11-10', 'Sat 23:00-03:00'),
('FW05', 'fw-dc2-edge-01', 'US-West', 'DC2-SanFrancisco', 'R08-U12', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.20.1.10', 'Network-Security', 'Critical', '2022-03-10', 'Sun 02:00-06:00'),
('FW06', 'fw-dc2-edge-02', 'US-West', 'DC2-SanFrancisco', 'R08-U13', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.20.1.11', 'Network-Security', 'Critical', '2022-03-10', 'Sun 02:00-06:00'),
('FW07', 'fw-dc2-internal-01', 'US-West', 'DC2-SanFrancisco', 'R10-U05', 'Internal Firewall', 'ASA-5525-X', '9.14.3', '10.20.2.10', 'Network-Security', 'Medium', '2020-11-05', 'Sat 22:00-02:00'),
('FW08', 'fw-dc2-dmz-01', 'US-West', 'DC2-SanFrancisco', 'R11-U08', 'DMZ Firewall', 'ASA-5545-X', '9.16.2', '10.20.3.10', 'Network-Security', 'High', '2021-09-12', 'Sun 01:00-05:00'),
('FW09', 'fw-dc3-edge-01', 'EU-West', 'DC3-London', 'R05-U20', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.30.1.10', 'Network-EMEA', 'Critical', '2022-06-01', 'Sun 01:00-05:00'),
('FW10', 'fw-dc3-edge-02', 'EU-West', 'DC3-London', 'R05-U21', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.30.1.11', 'Network-EMEA', 'Critical', '2022-06-01', 'Sun 01:00-05:00'),
('FW11', 'fw-dc3-dmz-01', 'EU-West', 'DC3-London', 'R07-U12', 'DMZ Firewall', 'ASA-5545-X', '9.16.2', '10.30.2.10', 'Network-EMEA', 'High', '2021-10-15', 'Sat 22:00-02:00'),
('FW12', 'fw-dc3-internal-01', 'EU-West', 'DC3-London', 'R09-U06', 'Internal Firewall', 'ASA-5525-X', '9.14.3', '10.30.3.10', 'Network-EMEA', 'Medium', '2020-12-08', 'Sun 02:00-06:00'),
('FW13', 'fw-dc4-edge-01', 'APAC', 'DC4-Singapore', 'R03-U08', 'Edge Firewall', 'ASA-5545-X', '9.16.2', '10.40.1.10', 'Network-APAC', 'Critical', '2021-12-15', 'Sun 03:00-07:00'),
('FW14', 'fw-dc4-edge-02', 'APAC', 'DC4-Singapore', 'R03-U09', 'Edge Firewall', 'ASA-5545-X', '9.16.2', '10.40.1.11', 'Network-APAC', 'Critical', '2021-12-15', 'Sun 03:00-07:00'),
('FW15', 'fw-dc4-dmz-01', 'APAC', 'DC4-Singapore', 'R03-U15', 'DMZ Firewall', 'ASA-5525-X', '9.14.3', '10.40.2.10', 'Network-APAC', 'High', '2021-05-20', 'Sat 23:00-03:00'),
('FW16', 'fw-dc5-edge-01', 'EU-Central', 'DC5-Frankfurt', 'R06-U18', 'Edge Firewall', 'ASA-5555-X', '9.16.4', '10.50.1.10', 'Network-EMEA', 'Critical', '2022-04-20', 'Sun 01:00-05:00'),
('FW17', 'fw-dc5-dmz-01', 'EU-Central', 'DC5-Frankfurt', 'R08-U10', 'DMZ Firewall', 'ASA-5545-X', '9.16.2', '10.50.2.10', 'Network-EMEA', 'High', '2022-04-20', 'Sun 01:00-05:00'),
('FW18', 'fw-dc6-edge-01', 'APAC', 'DC6-Sydney', 'R04-U12', 'Edge Firewall', 'ASA-5545-X', '9.16.2', '10.60.1.10', 'Network-APAC', 'Critical', '2022-07-10', 'Sun 04:00-08:00'),
('FW19', 'fw-dc6-internal-01', 'APAC', 'DC6-Sydney', 'R05-U08', 'Internal Firewall', 'ASA-5525-X', '9.14.3', '10.60.2.10', 'Network-APAC', 'Medium', '2021-03-25', 'Sun 05:00-09:00'),
('FW20', 'fw-branch-nyc-01', 'US-East', 'Branch-NYC', 'Wall-Mount-A', 'Branch Firewall', 'ASA-5506-X', '9.12.4', '10.70.1.10', 'Branch-Networks', 'Low', '2020-01-10', 'Sun 04:00-06:00'),
('FW21', 'fw-branch-chicago-01', 'US-Central', 'Branch-Chicago', 'Wall-Mount-B', 'Branch Firewall', 'ASA-5506-X', '9.12.4', '10.70.2.10', 'Branch-Networks', 'Low', '2020-02-15', 'Sun 03:00-05:00'),
('FW22', 'fw-branch-dallas-01', 'US-Central', 'Branch-Dallas', 'Wall-Mount-C', 'Branch Firewall', 'ASA-5508-X', '9.14.2', '10.70.3.10', 'Branch-Networks', 'Low', '2021-01-20', 'Sun 03:00-05:00'),
('FW23', 'fw-branch-seattle-01', 'US-West', 'Branch-Seattle', 'Wall-Mount-D', 'Branch Firewall', 'ASA-5506-X', '9.12.4', '10.70.4.10', 'Branch-Networks', 'Low', '2020-03-18', 'Sun 02:00-04:00'),
('FW24', 'fw-branch-boston-01', 'US-East', 'Branch-Boston', 'Wall-Mount-E', 'Branch Firewall', 'ASA-5508-X', '9.14.2', '10.70.5.10', 'Branch-Networks', 'Low', '2021-04-22', 'Sun 04:00-06:00'),
('FW25', 'fw-hub-miami-01', 'US-Southeast', 'Hub-Miami', 'R14-U10', 'Regional Hub', 'ASA-5545-X', '9.16.2', '10.80.1.10', 'Network-Regional', 'High', '2022-02-15', 'Sun 03:00-07:00'),
('FW26', 'fw-hub-toronto-01', 'CA-Central', 'Hub-Toronto', 'R11-U15', 'Regional Hub', 'ASA-5545-X', '9.16.2', '10.80.2.10', 'Network-Regional', 'High', '2022-05-10', 'Sun 02:00-06:00'),
('FW27', 'fw-hub-mumbai-01', 'APAC', 'Hub-Mumbai', 'R08-U20', 'Regional Hub', 'ASA-5525-X', '9.14.3', '10.80.3.10', 'Network-APAC', 'High', '2021-11-05', 'Sun 03:30-07:30'),
('FW28', 'fw-test-lab-01', 'US-East', 'DC1-NewYork', 'R20-U05', 'Test Firewall', 'ASA-5515-X', '9.16.4', '10.90.1.10', 'Engineering-QA', 'Low', '2020-06-12', 'Any Time'),
('FW29', 'fw-dr-backup-01', 'US-Central', 'DC7-Denver', 'R10-U12', 'DR Firewall', 'ASA-5555-X', '9.16.4', '10.90.2.10', 'Network-Security', 'Critical', '2022-08-01', 'Sun 02:00-06:00'),
('FW30', 'fw-dev-staging-01', 'US-West', 'DC2-SanFrancisco', 'R22-U08', 'Development Firewall', 'ASA-5515-X', '9.18.1', '10.90.3.10', 'Engineering-Dev', 'Low', '2023-01-10', 'Any Time');


CREATE VIEW cisco_o11y.v_enrich_with_assets_and_geolocation
AS
SELECT
  -- All fields from enhanced_asa_logs
  e.ingestion_time,
  e.log_timestamp,
  e.device_name,
  e.severity,
  e.message_id,
  e.asa_message,
  
  -- Network fields
  e.src_ip,
  e.dst_ip,
  e.src_port,
  e.dst_port,
  e.protocol,
  e.src_interface,
  e.dst_interface,

  -- Device/Asset fields from JOIN
  a.hostname AS device_hostname,
  a.location AS device_location,
  a.datacenter AS device_datacenter,
  a.rack_position AS device_rack_position,
  a.device_type AS device_type,
  a.hardware_model AS device_hardware_model,
  a.software_version AS device_software_version,
  a.management_ip AS device_management_ip,
  a.owner_team AS device_owner_team,
  a.criticality AS device_criticality,
  a.deployment_date AS device_deployment_date,
  a.maintenance_window AS device_maintenance_window,
  
  -- Computed fields
  (a.criticality = 'Critical') AS is_critical_device,
  date_diff('day', a.deployment_date, now()) AS device_age_days,
  
  -- Check if current time is within maintenance window
  -- Simple check for "Sun 02:00-06:00" format
  (
    to_day_of_week(now()) = 
      CASE 
        WHEN a.maintenance_window LIKE 'Sun%' THEN 7
        WHEN a.maintenance_window LIKE 'Mon%' THEN 1
        WHEN a.maintenance_window LIKE 'Tue%' THEN 2
        WHEN a.maintenance_window LIKE 'Wed%' THEN 3
        WHEN a.maintenance_window LIKE 'Thu%' THEN 4
        WHEN a.maintenance_window LIKE 'Fri%' THEN 5
        WHEN a.maintenance_window LIKE 'Sat%' THEN 6
        ELSE 0
      END
    AND
    hour(now()) >= to_uint8(extract(a.maintenance_window, '(\\d{2}):\\d{2}'))
    AND
    hour(now()) < to_uint8(extract(a.maintenance_window, '-(\\d{2}):\\d{2}'))
  ) OR (a.maintenance_window = 'Any Time') AS is_in_maintenance_window
FROM cisco_o11y.flatten_extracted_asa_logs e
LEFT JOIN cisco_o11y.device_assets a ON e.device_name = a.device_name;