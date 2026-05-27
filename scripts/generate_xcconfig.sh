#!/usr/bin/env bash
# Genera KafeCamSecrets.xcconfig a partir de variables de entorno de CI.
# xcconfig interpreta // como comentario, por eso las URLs HTTPS necesitan
# el truco de _SLASH para que no se trunque a "https:".
set -euo pipefail

: "${SUPABASE_URL:?La variable SUPABASE_URL no está definida}"
: "${SUPABASE_ANON_KEY:?La variable SUPABASE_ANON_KEY no está definida}"
: "${SENTRY_DSN:?La variable SENTRY_DSN no está definida}"

# https://foo.supabase.co → foo.supabase.co
SUPABASE_HOST="${SUPABASE_URL#https://}"

# https://key@org.ingest.sentry.io/id → key@org.ingest.sentry.io/id
SENTRY_HOST="${SENTRY_DSN#https://}"

cat > KafeCamSecrets.xcconfig << EOF
_SLASH = /
SUPABASE_URL = https:\$(_SLASH)\$(_SLASH)${SUPABASE_HOST}
SUPABASE_ANON_KEY = ${SUPABASE_ANON_KEY}
SENTRY_DSN = https:\$(_SLASH)\$(_SLASH)${SENTRY_HOST}
GENERATE_INFOPLIST_FILE = NO
INFOPLIST_FILE = KafeCam/Info.plist
EOF

echo "✓ KafeCamSecrets.xcconfig generado"
