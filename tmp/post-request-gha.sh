TOKEN=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
curl -X POST https://api.github.com/repos/petr-akimov/otus-final/dispatches \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d '{"event_type":"trigger-model","client_payload":{"MODEL_VERSION":"6"}}'