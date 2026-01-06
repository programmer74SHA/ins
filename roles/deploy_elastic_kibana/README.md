# ELK Stack Deployment Role

This Ansible role deploys Elasticsearch and Kibana using Docker Compose.

## Docker Image Handling

The role supports two methods for loading Docker images:

### 1. Pull from Docker Registry (Default)

By default, the role pulls images from Docker Hub with automatic retry logic:
- 4 retry attempts with exponential backoff (2s, 4s, 8s, 16s)
- Handles temporary network failures gracefully
- Configured with `elk_use_local_images: false` (default)

### 2. Load from Local tar.gz Files

For air-gapped environments or when Docker Hub is unavailable:

1. Save Docker images to tar.gz files:
   ```bash
   # On a machine with internet access
   docker pull docker.io/elastic/elasticsearch:8.15.5
   docker pull docker.io/elastic/kibana:8.15.5

   docker save docker.io/elastic/elasticsearch:8.15.5 | gzip > elasticsearch.tar.gz
   docker save docker.io/elastic/kibana:8.15.5 | gzip > kibana.tar.gz
   ```

2. Copy the tar.gz files to the role:
   ```bash
   cp elasticsearch.tar.gz roles/deploy_elastic_kibana/files/
   cp kibana.tar.gz roles/deploy_elastic_kibana/files/
   ```

3. Enable local images in your inventory or playbook:
   ```yaml
   elk_use_local_images: true
   ```

## Configuration Variables

See `defaults/main.yml` for all available configuration options.

Key variables:
- `elk_use_local_images`: Set to `true` to load from local tar.gz files (default: `false`)
- `elk_stack_version`: Version of Elasticsearch and Kibana (default: `8.15.5`)
- `elk_elasticsearch_password`: Password for the elastic user
- `elk_deploy_dir`: Directory where ELK stack will be deployed

## Troubleshooting

### Docker Hub Pull Failures

If you see errors like "failed to authorize" or "unexpected EOF" when pulling from Docker Hub:

1. The role automatically retries with exponential backoff
2. Check network connectivity: `curl -I https://auth.docker.io`
3. If persistent, consider using local images (see above)
4. For rate limiting issues, configure Docker Hub credentials

### Image Loading Issues

If local image loading fails:
1. Verify tar.gz files exist in `roles/deploy_elastic_kibana/files/`
2. Check file permissions
3. Verify tar.gz files are valid: `gunzip -t elasticsearch.tar.gz`

### Elasticsearch Authentication

The role configures Elasticsearch authentication using the `ELASTIC_PASSWORD` environment variable, which is the standard method for Elasticsearch 8.x. The password is set during initial container startup using the `elk_elasticsearch_password` variable.

Configuration:
- Password is set via `ELASTIC_PASSWORD` environment variable in docker-compose
- Healthcheck uses the same password for authentication
- No manual password reset is required

If you need to manually verify the password:
```bash
# Check Elasticsearch health
curl -u elastic:P@ssw0rdM@t@6810 http://localhost:9200/_cluster/health?pretty

# If you need to change the password after deployment
curl -X POST -u elastic:P@ssw0rdM@t@6810 \
  "http://localhost:9200/_security/user/elastic/_password" \
  -H "Content-Type: application/json" \
  -d '{"password":"your_new_password"}'
```
