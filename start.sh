sudo docker run -tid \
    -p 8000:80 \
    --name static \
    --restart on-failure \
    static

sudo docker logs static