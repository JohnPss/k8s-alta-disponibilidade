FROM python:3.12-slim

# Evita que o Python grave arquivos .pyc
ENV PYTHONDONTWRITEBYTECODE=1
# Evita que o Python faça buffer de stdout e stderr
ENV PYTHONUNBUFFERED=1

# Cria usuário não-root 'app' e o grupo correspondente
RUN groupadd -r app && useradd -r -g app app

# Define o diretório de trabalho
WORKDIR /app

# Copia o requirements.txt primeiro para aproveitar o cache do Docker
COPY requirements.txt .

# Instala as dependências sem usar cache local
RUN pip install --no-cache-dir -r requirements.txt

# Copia o restante do código da aplicação
COPY . .

# Muda a propriedade do diretório para o usuário 'app'
RUN chown -R app:app /app

# Altera para o usuário 'app'
USER app

# Expõe a porta 8080
EXPOSE 8080

# Comando para iniciar o servidor Gunicorn
CMD ["gunicorn", "-w", "2", "--threads", "2", "-b", "0.0.0.0:8080", "app:app"]
