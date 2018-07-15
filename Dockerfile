FROM python:3.6.5-slim-stretch

ENV JUPYTER_HOME /home/jupyter
RUN useradd -ms /bin/bash -d ${JUPYTER_HOME} jupyter

USER jupyter
WORKDIR ${JUPYTER_HOME}

COPY Pipfile Pipfile.lock ${JUPYTER_HOME}/
RUN python -m venv venv \
    && . venv/bin/activate \
    && pip install -U pip wheel pipenv \
    && pipenv install --deploy \
    && rm -rf ${JUPYTER_HOME}/.cache

COPY demo.ipynb ${JUPYTER_HOME}/

CMD ["venv/bin/jupyter", "notebook", "--no-browser"]
