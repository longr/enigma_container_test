FROM alpine:latest

COPY check_alpine_release.sh .

RUN chmod +x /check_alpine_release.sh

CMD ["/check_alpine_release.sh"]
