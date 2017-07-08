FROM swiftdocker/swift:3.1

RUN apt-get -y update \
  && apt-get install -y \
    wget \
    curl \
    git \
    clang \
    libicu-dev \
    binutils \
    libxml2-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN curl -sL https://apt.vapor.sh | bash \
  && apt-get update \
  && apt-get install -y vapor \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
