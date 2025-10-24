FROM postgres:17
COPY 01-logging.conf /docker-entrypoint-initdb.d/

ARG START_SCRIPT=/usr/local/bin/start.sh
ENV START_SCRIPT=${START_SCRIPT}

COPY run-postgres-with-json-logs-streamed-to-stdout.sh ${START_SCRIPT}
RUN chmod +x ${START_SCRIPT}

CMD ["bash", "-c", "${START_SCRIPT}"]