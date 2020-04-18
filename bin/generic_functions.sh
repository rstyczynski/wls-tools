
#!/bin/bash

function getMainIP() {
    ip route get 8.8.8.8 | head -1 | cut -d' ' -f7
}
