# syntax=docker/dockerfile:experimental

# Base image
FROM quay.io/unstructured-io/base-images:wolfi-base-latest AS base

# ===== Build args with safe defaults =====
ARG NB_USER=notebook-user
ARG NB_UID=1000
ARG PYTHON_VERSION=3.12
ARG PIP_VERSION=24.2
# مهم: پیش‌فرض به دایرکتوری موجود در ریپو می‌خورد
ARG PIPELINE_PACKAGE=general

# ===== Environment =====
ENV PYTHON=python${PYTHON_VERSION}
ENV PIP="${PYTHON} -m pip"
ENV PATH="/home/${NB_USER}/.local/bin:${PATH}"
ENV PYTHONPATH="/home/${NB_USER}:${PYTHONPATH}"

# محل کاربر را شفاف تنظیم می‌کنیم
WORKDIR /home/${NB_USER}
USER ${NB_USER}

# ===== Python deps stage =====
FROM base AS python-deps
COPY --chown=${NB_USER}:${NB_USER} requirements/base.txt requirements-base.txt
RUN ${PIP} install --upgrade pip==${PIP_VERSION} && \
    ${PIP} install --no-cache -r requirements-base.txt

# ===== Model deps stage =====
FROM python-deps AS model-deps
RUN ${PYTHON} -c "from unstructured.nlp.tokenize import download_nltk_packages; download_nltk_packages()" && \
    ${PYTHON} -c "from unstructured.partition.model_init import initialize; initialize()"

# ===== App code stage =====
FROM model-deps AS code
# فایل‌های جانبی
COPY --chown=${NB_USER}:${NB_USER} CHANGELOG.md CHANGELOG.md
COPY --chown=${NB_USER}:${NB_USER} logger_config.yaml logger_config.yaml

# کپی پوشه‌ی pipeline مطابق مقدار یا پیش‌فرض
# در ریپو فعلی معادل می‌شود: prepline_general/
COPY --chown=${NB_USER}:${NB_USER} prepline_${PIPELINE_PACKAGE}/ prepline_${PIPELINE_PACKAGE}/

# نوت‌بوک‌ها (اختیاری؛ اگر نمی‌خواهید، این خط را حذف کنید)
COPY --chown=${NB_USER}:${NB_USER} exploration-notebooks exploration-notebooks

# اسکریپت شروع
COPY --chown=${NB_USER}:${NB_USER} scripts/app-start.sh scripts/app-start.sh
RUN chmod +x scripts/app-start.sh

# شبکه
EXPOSE 8000

# اجرای سرویس
ENTRYPOINT ["scripts/app-start.sh"]
