!/bin/bash
# -------------------------------
# generate-certs.sh
# -------------------------------
set -e
if [ "$#" -lt 1 ]; then
echo "Usage: $0 <customer_name>"
exit 1
fi
CUSTOMER_NAME=$1
CERT_DIR="./certs/$CUSTOMER_NAME"
mkdir -p "$CERT_DIR"
KEY_FILE="$CERT_DIR/key.pem"
CSR_FILE="$CERT_DIR/csr.pem"
CERT_FILE="$CERT_DIR/cert.pem"
OPENSSL_CNF="$CERT_DIR/openssl.cnf"
cat > "$OPENSSL_CNF" <<EOL
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
prompt = no
[ req_distinguished_name ]
C = IR
ST = Tehran
L = Tehran
O = APK-Group
OU = DevOps
CN = elasticsearch-$CUSTOMER_NAME
[ req_ext ]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
[ alt_names ]
DNS.1 = elasticsearch
#DNS.2 = .apk-group.net
EOL
openssl genrsa -out "$KEY_FILE" 2048
openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -config "$OPENSSL_CNF"
openssl x509 -req -in "$CSR_FILE" -signkey "$KEY_FILE" -out "$CERT_FILE" -days 365 -extensions req_ext -extfile "$OPENSSL_CNF"
echo "TLS certificate generated for customer: $CUSTOMER_NAME"
echo "Files saved in: $CERT_DIR"
echo " - Key: $KEY_FILE"
echo " - CSR: $CSR_FILE"
echo " - Certificate: $CERT_FILE"
