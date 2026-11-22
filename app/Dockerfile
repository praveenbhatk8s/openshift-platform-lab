# Red Hat's Python base image is built for OpenShift: it runs as a non-root user in group 0,
# and its app directory is group-writable, so any UID that OpenShift assigns can run it.
FROM registry.access.redhat.com/ubi9/python-312:latest

COPY --chown=1001:0 app.py /opt/app-root/src/app.py

USER 1001
EXPOSE 8080 8443
CMD ["python3", "/opt/app-root/src/app.py"]
