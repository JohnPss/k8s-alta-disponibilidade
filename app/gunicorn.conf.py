# O worker gthread (--threads) descarta o header Connection da aplicação
# e responde keep-alive. Com keepalive = 0 o Gunicorn manda Connection: close,
# como o contrato exige (o kube-proxy balanceia por conexão).
keepalive = 0
