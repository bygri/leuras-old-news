FROM python:3 as builder
WORKDIR /app
COPY . .
RUN pip3 install -r requirements.txt
RUN python build.py

FROM nginx:alpine
COPY --from=builder /app/www /usr/share/nginx/html
