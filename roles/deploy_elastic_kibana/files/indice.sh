#!/bin/bash

# Elasticsearch Setup Script
# This script creates ILM policies, ingest pipelines, and index templates

# Configuration
ES_HOST="localhost:9200"
ES_USER="elastic"
ES_PASSWORD="P@ssw0rdM@t@6810"
ES_PROTOCOL="http"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to make API calls
es_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4

    echo -e "${YELLOW}[INFO]${NC} $description"

    if [ -n "$ES_PASSWORD" ]; then
        AUTH="-u $ES_USER:$ES_PASSWORD"
    else
        AUTH=""
    fi

    response=$(curl -s -w "\n%{http_code}" $AUTH -X $method \
        "$ES_PROTOCOL://$ES_HOST$endpoint" \
        -H 'Content-Type: application/json' \
        -d "$data")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} HTTP $http_code"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo -e "${RED}[ERROR]${NC} HTTP $http_code"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
        return 1
    fi
    echo ""
}

echo "=========================================="
echo "Elasticsearch Configuration Setup"
echo "=========================================="
echo "Host: $ES_PROTOCOL://$ES_HOST"
echo "User: $ES_USER"
echo "=========================================="
echo ""

# 1. Create "apk-ai" ILM Policy
es_call "PUT" "/_ilm/policy/apk-ai" '{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "14d",
            "max_primary_shard_size": "10gb"
          },
          "forcemerge": {
            "max_num_segments": 1
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "delete": {
        "min_age": "120d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}' "Creating ILM policy: apk-ai"

# 2. Create "apk-ai" Ingest Pipeline
es_call "PUT" "/_ingest/pipeline/apk-ai" '{
  "description": "by mosy\nv1.0.0",
  "processors": [
    {
      "script": {
        "source": "if (ctx?.ai_ingested_time == null) { ctx.ai_ingested_time = metadata().now.withNano(0).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME); }",
        "ignore_failure": true,
        "description": "Add time when event was ingested (and remove sub-seconds to improve storage efficiency)"
      }
    },
    {
      "script": {
        "source": "ctx.ai_timestamp = metadata().now.withNano(0).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);",
        "if": "ctx?.ai_timestamp == null",
        "ignore_failure": true,
        "description": "add ai_timestamp with Nowtime()"
      }
    },
    {
      "set": {
        "field": "@timestamp",
        "copy_from": "ai_ingested_time",
        "ignore_empty_value": true,
        "if": "ctx?.ai_timestamp == null",
        "ignore_failure": true,
        "description": "if not exist use ai_ingested_time"
      }
    },
    {
      "date": {
        "field": "ai_timestamp",
        "formats": [
          "ISO8601",
          "UNIX",
          "UNIX_MS",
          "TAI64N"
        ],
        "target_field": "@timestamp",
        "if": "ctx?.ai_timestamp != null",
        "ignore_failure": true,
        "description": "add @timestamp based on ai_timestamp"
      }
    },
    {
      "remove": {
        "field": "ai_timestamp",
        "ignore_missing": true,
        "ignore_failure": true
      }
    }
  ]
}' "Creating ingest pipeline: apk-ai"

# 3. Create "apk-ai" Index Template
es_call "PUT" "/_index_template/apk-ai" '{
  "priority": 200,
  "template": {
    "settings": {
      "index": {
        "lifecycle": {
          "name": "apk-ai"
        },
        "mode": "standard",
        "codec": "best_compression",
        "default_pipeline": "apk-ai",
        "mapping": {
          "total_fields": {
            "ignore_dynamic_beyond_limit": "true"
          },
          "ignore_malformed": "true"
        },
        "number_of_replicas": "0"
      }
    },
    "mappings": {
      "properties": {
        "ai_ingested_time": {
          "type": "date"
        },
        "@timestamp": {
          "type": "date"
        }
      }
    }
  },
  "index_patterns": [
    "timeline-*"
  ],
  "composed_of": [],
  "ignore_missing_component_templates": []
}' "Creating index template: apk-ai"

# 4. Create "smart-analyzer" ILM Policy
es_call "PUT" "/_ilm/policy/smart-analyzer" '{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "forcemerge": {
            "max_num_segments": 1
          },
          "rollover": {
            "max_age": "7d",
            "max_primary_shard_size": "128mb"
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "delete": {
        "min_age": "180d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}' "Creating ILM policy: smart-analyzer"

# 5. Create "smart-analyzer" Index Template
es_call "PUT" "/_index_template/smart-analyzer" '{
  "version": 1,
  "priority": 500,
  "template": {
    "settings": {
      "index": {
        "lifecycle": {
          "name": "smart-analyzer"
        },
        "mode": "standard",
        "codec": "best_compression",
        "mapping": {
          "total_fields": {
            "limit": "1000",
            "ignore_dynamic_beyond_limit": "true"
          },
          "ignore_malformed": "true"
        },
        "number_of_shards": "1",
        "number_of_replicas": "0"
      }
    },
    "mappings": {
      "dynamic_templates": [],
      "properties": {
        "AI": {
          "type": "object",
          "properties": {
            "response": {
              "type": "text"
            },
            "request_data": {
              "type": "text"
            },
            "type": {
              "type": "keyword"
            },
            "attempt": {
              "type": "integer"
            }
          }
        }
      }
    }
  },
  "index_patterns": [
    "logs-smart_analyzer-*"
  ],
  "data_stream": {
    "hidden": false,
    "allow_custom_routing": false
  },
  "composed_of": [],
  "ignore_missing_component_templates": []
}' "Creating index template: smart-analyzer"

# 6. Create "apk-error" ILM Policy
es_call "PUT" "/_ilm/policy/apk-error" '{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "7d",
            "max_primary_shard_size": "10gb"
          },
          "forcemerge": {
            "max_num_segments": 1
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}' "Creating ILM policy: apk-error"

# 7. Create "apksoar-error" Index Template
es_call "PUT" "/_index_template/apksoar-error" '{
  "priority": 200,
  "template": {
    "settings": {
      "index": {
        "mode": "standard",
        "lifecycle": {
          "name": "apk-error"
        }
      }
    },
    "mappings": {
      "_source": {
        "mode": "synthetic"
      },
      "dynamic_templates": [],
      "properties": {
        "data_stream": {
          "type": "object",
          "properties": {
            "namespace": {
              "type": "constant_keyword",
              "value": "default"
            },
            "type": {
              "type": "constant_keyword",
              "value": "logs"
            },
            "dataset": {
              "type": "constant_keyword",
              "value": "apksoar.error"
            }
          }
        },
        "event": {
          "type": "object",
          "properties": {
            "module": {
              "type": "constant_keyword",
              "value": "apksoar"
            }
          }
        }
      }
    }
  },
  "index_patterns": [
    "logs-apksoar.error-*"
  ],
  "data_stream": {
    "hidden": false,
    "allow_custom_routing": false
  },
  "composed_of": [],
  "ignore_missing_component_templates": []
}' "Creating index template: apksoar-error"

# 8. Create "apksoar-unchecked" Index Template
es_call "PUT" "/_index_template/apksoar-unchecked" '{
  "priority": 200,
  "template": {
    "settings": {
      "index": {
        "mode": "standard",
        "lifecycle": {
          "name": "apk-ai"
        }
      }
    },
    "mappings": {
      "_source": {
        "mode": "synthetic"
      },
      "dynamic_templates": [],
      "properties": {
        "data_stream": {
          "type": "object",
          "properties": {
            "namespace": {
              "type": "constant_keyword",
              "value": "default"
            },
            "type": {
              "type": "constant_keyword",
              "value": "logs"
            },
            "dataset": {
              "type": "constant_keyword",
              "value": "apksoar.unchecked"
            }
          }
        },
        "event": {
          "type": "object",
          "properties": {
            "module": {
              "type": "constant_keyword",
              "value": "apksoar"
            }
          }
        }
      }
    }
  },
  "index_patterns": [
    "logs-apksoar.unchecked-*"
  ],
  "data_stream": {
    "hidden": false,
    "allow_custom_routing": false
  },
  "composed_of": [],
  "ignore_missing_component_templates": []
}' "Creating index template: apksoar-unchecked"

# 9. Create index template for logs-nessus_scan-default (uses apk-ai policy)
es_call "PUT" "/_index_template/logs-nessus_scan" '{
  "priority": 300,
  "template": {
    "settings": {
      "index": {
        "lifecycle": {
          "name": "apk-ai"
        },
        "mode": "standard",
        "codec": "best_compression",
        "default_pipeline": "apk-ai",
        "number_of_replicas": "0",
        "number_of_shards": "1",
        "mapping": {
          "ignore_malformed": true
        }
      }
    },
    "mappings": {
      "_source": { "enabled": true },
      "properties": {
        "data_stream": {
          "type": "object",
          "properties": {
            "dataset": { "type": "constant_keyword", "value": "nessus_scan" },
            "namespace": { "type": "constant_keyword", "value": "default" },
            "type": { "type": "constant_keyword", "value": "logs" }
          }
        },
        "event": {
          "properties": {
            "module": { "type": "constant_keyword", "value": "nessus" }
          }
        }
      }
    }
  },
  "index_patterns": ["logs-nessus_scan-*"],
  "data_stream": { }
}' "Creating index template: logs-nessus_scan-default"

# 10. Create index template for ticketing-last-sync-checkpoint (small control index)
es_call "PUT" "/_index_template/ticketing-last-sync-checkpoint" '{
  "priority": 400,
  "template": {
    "settings": {
      "index": {
        "lifecycle": {
          "name": "ticketing-checkpoint"
        },
        "mode": "standard",
        "codec": "best_compression",
        "number_of_shards": 1,
        "number_of_replicas": 0,
        "hidden": true
      }
    },
    "mappings": {
      "properties": {
        "last_sync_time": { "type": "date" },
        "system": { "type": "keyword" },
        "status": { "type": "keyword" },
        "records_processed": { "type": "long" }
      }
    }
  },
  "index_patterns": ["ticketing-last-sync-checkpoint*"]
}' "Creating index template: ticketing-last-sync-checkpoint"

echo "=========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=========================================="
