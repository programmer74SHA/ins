# Deploy Smart Analyzer Role

This Ansible role deploys the Smart Analyzer application stack, which includes:

- **AI Service**: Main smart analyzer service that handles AI-powered security analysis
- **Qdrant**: Vector database for storing and retrieving security-related data
- **HAProxy**: Load balancer for AI launcher services
- **AI Launcher 1 & 2**: VLLM-based AI model inference services with GPU support
- **Text Embeddings Inference**: Text embedding generation service

## Requirements

- Docker installed on the target host
- NVIDIA GPU and nvidia-docker runtime (for AI launchers and embeddings service)
- Docker networks: `smart-analyzer-network` and `esnet` (created automatically if `*_external` is set to true)
- Sufficient disk space for models and data storage
- community.docker Ansible collection installed

## Role Variables

### Deployment Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `smart_analyzer_deploy_dir` | `/data/ai/smart-analyzer` | Base deployment directory |
| `smart_analyzer_use_project_env` | `true` | Use project .env file instead of templated one |
| `smart_analyzer_build_ai_service` | `false` | Build AI service image locally |

### Docker Images

| Variable | Default | Description |
|----------|---------|-------------|
| `smart_analyzer_ai_service_image` | `registry.apk-group.net/automation/modules/smart-analyzer-ai:1.0.41` | AI service image |
| `smart_analyzer_qdrant_image` | `registry.apk-group.net/automation/modules/qdrant:1.14.1` | Qdrant vector DB image |
| `smart_analyzer_haproxy_image` | `haproxy:alpine` | HAProxy load balancer image |
| `smart_analyzer_vllm_image` | `registry.apk-group.net/automation/vllm/vllm-openai:latest` | VLLM inference image |
| `smart_analyzer_embeddings_image` | `ghcr.io/huggingface/text-embeddings-inference:latest` | Text embeddings image |

### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `smart_analyzer_network_name` | `smart-analyzer-network` | Main Docker network name |
| `smart_analyzer_network_external` | `true` | Create network if it doesn't exist |
| `smart_analyzer_esnet_name` | `esnet` | Elasticsearch network name |
| `smart_analyzer_esnet_external` | `true` | Create esnet if it doesn't exist |

### Port Mappings

| Variable | Default | Description |
|----------|---------|-------------|
| `smart_analyzer_ai_service_port` | `2181` | AI service API port |
| `smart_analyzer_qdrant_port` | `6333` | Qdrant API port |
| `smart_analyzer_haproxy_port` | `5002` | HAProxy port |
| `smart_analyzer_ai_launcher_1_port` | `5005` | AI Launcher 1 port |
| `smart_analyzer_ai_launcher_2_port` | `5003` | AI Launcher 2 port |
| `smart_analyzer_embeddings_port` | `3030` | Embeddings service port |

### AI Model Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `smart_analyzer_ai_model_path` | `/models/Qwen3-30B-A3B-Instruct-2507-FP8` | Path to AI model |
| `smart_analyzer_ai_tensor_parallel_size` | `1` | Tensor parallelism degree |
| `smart_analyzer_ai_gpu_memory_utilization` | `0.8` | GPU memory usage fraction |
| `smart_analyzer_ai_max_model_len` | `32768` | Maximum model context length |
| `smart_analyzer_ai_max_num_seqs` | `8` | Max parallel sequences |
| `smart_analyzer_ai_max_num_batched_tokens` | `4096` | Max batched tokens |

### Application Environment Variables

All environment variables from the original docker-compose.yml can be configured through role variables with the `smart_analyzer_` prefix. See `defaults/main.yml` for the complete list.

Key application variables:
- Vault configuration
- Elasticsearch/Splunk integration
- Jira integration and custom fields
- Vector database settings
- Embedding LLM configuration

## Dependencies

None.

## Example Playbook

### Basic Usage

```yaml
- name: Deploy Smart Analyzer
  hosts: ai_servers
  become: yes
  roles:
    - deploy_smart_analyzer
```

### Custom Configuration

```yaml
- name: Deploy Smart Analyzer with custom settings
  hosts: ai_servers
  become: yes
  vars:
    smart_analyzer_deploy_dir: /opt/smart-analyzer
    smart_analyzer_ai_service_port: 3000
    smart_analyzer_elasticsearch_host: "elasticsearch.example.com"
    smart_analyzer_elasticsearch_port: 9200
    smart_analyzer_jira_host: "jira.example.com"
    smart_analyzer_use_project_env: false
  roles:
    - deploy_smart_analyzer
```

### Building AI Service Image Locally

```yaml
- name: Deploy Smart Analyzer with local build
  hosts: ai_servers
  become: yes
  vars:
    smart_analyzer_build_ai_service: true
    smart_analyzer_dockerfile_path: /path/to/smart-analyzer/source
  roles:
    - deploy_smart_analyzer
```

## Directory Structure

The role creates the following directory structure on the target host:

```
/data/ai/smart-analyzer/          # Base deployment directory
├── .env                          # Environment configuration
├── models/                       # AI models directory
├── infra_config/
│   └── haproxy/                 # HAProxy configuration
/usr/share/mssp/prompts/         # Prompts directory
/data/db/issue_database/         # Qdrant storage
```

## Post-Deployment

After deployment:

1. Verify all containers are running:
   ```bash
   docker ps | grep -E 'smart-analyzer|qdrant|haproxy|ai-launcher|text-embeddings'
   ```

2. Check AI Service health:
   ```bash
   curl http://localhost:2181/health
   ```

3. Verify Qdrant is accessible:
   ```bash
   curl http://localhost:6333/collections
   ```

## Troubleshooting

### GPU Issues

If AI launchers fail to start, verify:
- NVIDIA drivers are installed: `nvidia-smi`
- nvidia-docker runtime is configured: `docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi`

### Network Issues

If containers can't communicate:
- Verify networks exist: `docker network ls`
- Check network configuration: `docker network inspect smart-analyzer-network`

### Container Logs

View logs for specific services:
```bash
docker logs smart-analyzer
docker logs ai-launcher-1
docker logs qdrant
```

## License

APK-Group

## Author Information

Generated from docker-compose.yml configuration for Smart Analyzer deployment.
