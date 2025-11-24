#!/usr/bin/env bash
# Script personnel pour mettre en place des machines virtuelles

QEMU="/c/QEMU/qemu/build/qemu-system-x86_64.exe"
DISK_DIR="$HOME/vms"
QEMU_IMG="/c/QEMU/qemu/build/qemu-img.exe"

RAM_MB=4096
CPU_CORES=2

setup() {

    $QEMU_IMG create -f qcow2 $DISK_DIR/london-dc.qcow2 50G
    echo "London disk created"

    $QEMU_IMG create -f qcow2 $DISK_DIR/mgmt-iis-ca.qcow2 50G
    echo "Management disk created"

    $QEMU_IMG create -f qcow2 $DISK_DIR/liverpool.qcow2 50G
    echo "Liverpool disk created"

    $QEMU_IMG create -f qcow2 $DISK_DIR/client.qcow2 50G
    echo "Client disk created"
}

start_london_dc() {
  "$QEMU" \
    -name "london-dc" \
    -m "$RAM_MB" \
    -smp cores="$CPU_CORES" \
    -machine type=pc,accel=tcg \
    -cdrom $HOME/iso/winserv.ISO \
    -drive file="$DISK_DIR/london-dc.qcow2",if=ide \
    -netdev socket,id=mynet,listen=:12345 \
    -device e1000,netdev=mynet \
    -boot c &
}

start_mgmt_iis_ca() {
  "$QEMU" \
    -name "mgmt-iis-ca" \
    -m "$RAM_MB" \
    -smp cores="$CPU_CORES" \
    -machine type=pc,accel=tcg \
    -cdrom $HOME/iso/winserv.ISO \
    -drive file="$DISK_DIR/mgmt-iis-ca.qcow2",if=ide \
    -netdev socket,id=mynet,connect=127.0.0.1:12345 \
    -device e1000,netdev=mynet \
    -boot c &
}

start_liverpool() {
  "$QEMU" \
    -name "liverpool" \
    -m "$RAM_MB" \
    -smp cores="$CPU_CORES" \
    -machine type=pc,accel=tcg \
    -cdrom $HOME/iso/winserv.ISO \
    -drive file="$DISK_DIR/liverpool.qcow2",if=ide \
    -netdev socket,id=mynet,connect=127.0.0.1:12345 \
    -device e1000,netdev=mynet \
    -boot c &
}

start_client() {
  "$QEMU" \
    -name "client" \
    -m 2048 \
    -smp cores=1 \
    -machine type=pc,accel=tcg \
    -cdrom $HOME/iso/win10.ISO \
    -drive file="$DISK_DIR/client.qcow2",if=ide \
    -netdev socket,id=mynet,connect=127.0.0.1:12345 \
    -device e1000,netdev=mynet \
    -boot c &
}

start_all() {
  echo "Starting London DC (hub)..."
  start_london_dc
  sleep 5

  echo "Starting mgmt IIS/CA..."
  start_mgmt_iis_ca

  echo "Starting Liverpool..."
  start_liverpool

  echo "Starting client..."
  start_client
}

case "$1" in
  setup)
    setup
    ;;
  london)
    start_london_dc
    ;;
  mgmt)
    start_mgmt_iis_ca
    ;;
  liverpool)
    start_liverpool
    ;;
  client)
    start_client
    ;;
  all)
    start_all
    ;;
  *)
    echo "Usage: $0 {setup|london|mgmt|liverpool|client|all}"
    ;;
esac
