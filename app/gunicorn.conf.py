# O worker gthread (--threads) descarta o header Connection da aplicação
# e responde keep-alive. Com keepalive = 0 o Gunicorn manda Connection: close,
# como o contrato exige (o kube-proxy balanceia por conexão).
keepalive = 0

# Gunicorn 27+ tenta criar o control socket em $HOME/.gunicorn/gunicorn.ctl,
# mas o usuário não-root 'app' não tem diretório /home/app gravável.
control_socket_disable = True
