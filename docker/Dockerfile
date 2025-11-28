FROM almalinux:9.3

RUN dnf -y update && \
	dnf install -y --allowerasing sudo curl && \
	dnf clean all

# Mount the entire workspace as a volume at /project
VOLUME ["/project"]

CMD ["/bin/bash"]
