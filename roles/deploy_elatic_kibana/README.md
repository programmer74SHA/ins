# Deploy Elasticsearch and Kibana Role

This Ansible role deploys Elasticsearch and Kibana stack using Docker Compose with TLS certificate generation.

## Requirements

### Ansible Collections

Install required collections using:

```bash
ansible-galaxy collection install -r requirements.yml
```

Required collections:
- `community.docker` (>=3.0.0) - For Docker and Docker Compose management
- `community.crypto` (>=2.0.0) - For TLS certificate generation

### System Requirements

- Docker and Docker Compose installed on target host
- Python packages: `docker`, `docker-compose`

## Role Variables

### Version Configuration
- `elk_stack_version`: Version of Elastic products (default: `8.15.5`)

### Elasticsearch Configuration
- `elk_elasticsearch_password`: Elasticsearch password (default: `P@ssw0rdM@t@6810`)
- `elk_elasticsearch_port`: Elasticsearch port (default: `9200`)
- `elk_es_java_heap`: Java heap size (default: `1g`)

### Kibana Configuration
- `elk_kibana_password`: Kibana password (default: `changeme`)
- `elk_kibana_port`: Kibana port (default: `5601`)
- `elk_kibana_service_account_token`: Service account token
- `elk_kibana_public_base_url`: Public base URL for Kibana
- `elk_kibana_encryption_key`: Encryption key for Kibana

### Network Configuration
- `elk_network_name`: Docker network name (default: `esnet`)
- `elk_network_external`: Whether to create external network (default: `true`)

### Deployment Configuration
- `elk_deploy_dir`: Deployment directory (default: `/opt/elk`)
- `elk_customer_name`: Customer name for certificate generation (default: `APK`)

### Certificate Configuration
- `elk_cert_country`: Country code (default: `IR`)
- `elk_cert_state`: State/Province (default: `Tehran`)
- `elk_cert_locality`: Locality/City (default: `Tehran`)
- `elk_cert_organization`: Organization name (default: `APK-Group`)
- `elk_cert_organizational_unit`: Organizational unit (default: `DevOps`)

### Indices Configuration
- `elk_setup_indices`: Whether to run indices setup (default: `true`)
- `elk_es_host`: Elasticsearch host for setup (default: `localhost:9200`)
- `elk_es_user`: Elasticsearch user (default: `elastic`)
- `elk_es_protocol`: Protocol for Elasticsearch (default: `http`)

## Certificate Generation

The role automatically generates self-signed TLS certificates for Elasticsearch using native Ansible tasks (previously used `generate_cert.sh` shell script).

Generated files:
- `{{ elk_deploy_dir }}/certs/{{ elk_customer_name }}/key.pem` - Private key
- `{{ elk_deploy_dir }}/certs/{{ elk_customer_name }}/csr.pem` - Certificate signing request
- `{{ elk_deploy_dir }}/certs/{{ elk_customer_name }}/cert.pem` - Self-signed certificate
- `{{ elk_deploy_dir }}/certs/{{ elk_customer_name }}/openssl.cnf` - OpenSSL configuration

Certificate properties:
- **Key Size**: 2048-bit RSA
- **Validity**: 365 days
- **Subject Alternative Names**: DNS:elasticsearch
- **Key Usage**: digitalSignature, keyEncipherment
- **Extended Key Usage**: serverAuth, clientAuth

## Example Playbook

```yaml
- hosts: elk_servers
  become: yes
  roles:
    - role: deploy_elatic_kibana
      vars:
        elk_customer_name: "my-company"
        elk_elasticsearch_password: "secure-password"
        elk_kibana_encryption_key: "my-secret-encryption-key-min-32-chars"
```

## Migration Notes

### Certificate Generation Refactoring

The certificate generation has been refactored from a shell script (`generate_cert.sh`) to native Ansible tasks:

**Before:**
- Used `generate_cert.sh` shell script
- Required copying script to target host
- Used `command` module to execute

**After:**
- Uses `community.crypto` collection modules
- Pure Ansible implementation
- Idempotent certificate generation
- Better error handling and validation

The old `generate_cert.sh` script has been preserved in `files/` directory for reference but is no longer used.

## License

MIT

## Author

DevOps Team - APK-Group
