FROM alpine:3.4
COPY foo_b_b /foo_b_b
EXPOSE 8080
CMD ["./foo_b_b"]
