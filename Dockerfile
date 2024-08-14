FROM ghcr.io/linuxserver/unrar as unrar

FROM ghcr.io/linuxserver/baseimage-alpine:edge as compile_env

# remove miniupnpc-dev cause the incompatibility of function UPNP_GetValidIGD
# transmission will use third-party compiled static library instead
RUN echo "*** install base packages ***" \
    && apk --no-cache add curl jq ca-certificates cmake curl-dev fmt-dev g++ gettext-dev git libevent-dev libpsl linux-headers ninja npm pkgconfig xz \
    && echo "*** Get customized transmission ***" \
    && git clone -b 4.0.x https://github.com/atomwh/transmission.git \
    && cd transmission && git submodule update --init --recursive && cd .. \
    && echo "*** Update registry of npm ***" \
    && npm config set registry=https://registry.npmmirror.com \
    && echo "*** Start to complie transmission ***" \
    && cmake -S transmission -B obj -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=pfx \
         -DENABLE_DAEMON=ON -DENABLE_UTILS=ON -DREBUILD_WEB=ON -DENABLE_TESTS=ON -DENABLE_WERROR=ON \
         -DENABLE_GTK=OFF -DENABLE_QT=OFF -DENABLE_MAC=OFF -DRUN_CLANG_TIDY=OFF \
    && cmake --build obj --config RelWithDebInfo \
    && cmake -E chdir obj ctest -j $(nproc) --build-config RelWithDebInfo --output-on-failure \
    && cmake --build obj --config RelWithDebInfo --target install/strip \
    && echo "*** Get customized TrguiNG ***" \
    && latest_rel="$(curl -s https://api.github.com/repos/atomwh/Trguing-cn/releases/latest | jq -r ".assets[].browser_download_url")" \
    && curl -L "$latest_rel" -o trguing.zip \
    && mkdir -p /trguing \
    && unzip -d /trguing trguing.zip

FROM ghcr.io/linuxserver/baseimage-alpine:edge

LABEL maintainer="jq50n"

RUN echo "*** install packages ***" \
    && apk add --no-cache findutils p7zip python3 libevent \
    && echo "**** cleanup ****" \
    && rm -rf /tmp/* $HOME/.cache

# add transmission
COPY --from=compile_env pfx/ /usr

# add TrguiNG
COPY --from=compile_env /trguing /trguing

# copy local files
COPY root/ /

# add unrar
COPY --from=unrar /usr/bin/unrar-alpine /usr/bin/unrar

ENV TRANSMISSION_WEB_HOME=/trguing \
    TZ=Asia/Shanghai 

# ports and volumes
ENV RPCPORT=9091 \
    PEERPORT=51413
EXPOSE $RPCPORT $PEERPORT/tcp $PEERPORT/udp
VOLUME /config
