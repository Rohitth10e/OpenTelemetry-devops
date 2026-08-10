# Networking Concepts for Terraform on AWS

This guide explains core networking ideas used in Infrastructure as Code (IaC), especially with AWS and Terraform. It is written for beginners and builds from basics to practical request flow.

## 1) What is a Network in Cloud?

A cloud network is a logically isolated space where your resources (servers, databases, load balancers) communicate.

In AWS, this isolated network is called a **VPC (Virtual Private Cloud)**.

Think of it like:
- **VPC** = your private city boundary
- **Subnets** = neighborhoods
- **Route tables** = road maps
- **IGW/NAT** = city gates to the internet
- **Security Groups/NACLs** = security checkpoints

---

## 2) VPC (Virtual Private Cloud)

A **VPC** is your private network inside AWS.

Key points:
- You choose its IP range using CIDR (for example `10.0.0.0/16`)
- You can create multiple subnets inside it
- Resources inside one VPC can usually talk to each other (subject to security rules)
- By default, a custom VPC is isolated from the internet until you attach an IGW and configure routes

### CIDR quick idea
- `10.0.0.0/16` gives ~65,536 addresses
- Subnets split this range, e.g. `10.0.1.0/24`, `10.0.2.0/24`

---

## 3) Subnets (Public vs Private)

A **subnet** is a smaller IP range inside a VPC. Each subnet exists in one Availability Zone (AZ).

### Public subnet
A subnet is called “public” when:
1. It has a route to an Internet Gateway (IGW), and
2. Instances have public IPs (or Elastic IPs)

Used for:
- Load balancers
- Bastion hosts
- Public-facing services

### Private subnet
A subnet with no direct route to IGW for outbound internet from instances.

Used for:
- App servers
- Databases
- Internal services

Private resources can still get outbound internet (for updates/package download) using NAT.

---

## 4) Internet Gateway (IGW)

An **Internet Gateway** is attached to a VPC and enables internet connectivity.

It is required for:
- Inbound internet traffic to public resources
- Outbound internet traffic from public subnets

Important:
- Just attaching IGW is not enough
- Route tables must send internet-bound traffic (`0.0.0.0/0`) to IGW
- Security groups/NACLs must allow traffic

---

## 5) NAT (Network Address Translation)

**NAT** allows private subnet resources to access the internet **outbound only**, without allowing inbound internet access back to them.

AWS options:
- **NAT Gateway** (managed, recommended)
- NAT Instance (self-managed EC2, less preferred)

Typical use:
- Private EC2 instances install packages, pull updates, call external APIs
- Internet cannot directly initiate connection to those private instances

Flow:
Private EC2 -> Route table (`0.0.0.0/0`) -> NAT Gateway (in public subnet) -> IGW -> Internet

---

## 6) IPv4 and IPv6

### IPv4
- 32-bit addresses (e.g., `192.168.1.10`)
- Most common today
- Limited global address space

### IPv6
- 128-bit addresses (very large space, e.g., `2001:db8::1`)
- Increasing cloud adoption
- Supports modern internet scale better

In AWS:
- VPC can have IPv4, IPv6, or dual-stack
- IPv6 internet egress usually uses **Egress-Only Internet Gateway** (for outbound-only behavior with IPv6)

---

## 7) Route Tables

A **route table** decides where traffic from a subnet goes.

Each route entry has:
- Destination (CIDR block)
- Target (local, IGW, NAT, peering, TGW, etc.)

Common routes:
- `10.0.0.0/16 -> local` (inside VPC)
- `0.0.0.0/0 -> igw-xxxx` (public internet via IGW)
- `0.0.0.0/0 -> nat-xxxx` (private subnet internet egress)
- `::/0 -> eigw-xxxx` (IPv6 egress-only)

Each subnet is associated with one route table.

---

## 8) Security Layers: Security Groups and NACLs

### Security Group (SG)
- Attached to ENI/instance level
- Stateful (response traffic automatically allowed)
- Allow rules only (no explicit deny)

### Network ACL (NACL)
- Attached to subnet level
- Stateless (need explicit inbound + outbound rules)
- Supports allow and deny

Beginner rule of thumb:
- Use SGs for most access control
- Use NACLs for broader subnet guardrails

---

## 9) Request Flow (End-to-End Example)

Example: User opens a web app hosted on EC2 behind a load balancer.

1. User hits domain (DNS resolves to load balancer)
2. Traffic enters VPC through IGW
3. Route table sends it to public subnet where load balancer lives
4. SG on load balancer allows `443` (HTTPS)
5. Load balancer forwards to app servers in private subnet
6. App SG allows traffic from load balancer SG
7. App queries database in private subnet (DB SG allows only app SG)
8. Response returns back through the same chain

If app server needs internet update:
- App subnet route sends `0.0.0.0/0` to NAT Gateway
- NAT sends outbound to internet via IGW

---

## 10) SSH Basics (Secure Shell)

**SSH** is used for secure remote terminal access (usually port `22`) to Linux servers.

Important practices:
- Use key-based auth, avoid password auth
- Restrict source IP in SG (never open `22` to entire internet in production)
- Prefer Bastion host or AWS Systems Manager Session Manager
- Rotate keys and enforce least privilege

Typical SSH path:
Laptop -> IGW -> Bastion (public subnet) -> private instance (via internal network)

---

## 11) SSL/TLS and HTTPS

People often say “SSL,” but modern secure web traffic uses **TLS**.

### Why TLS/HTTPS matters
- Encrypts data in transit
- Prevents man-in-the-middle tampering
- Verifies server identity via certificates

Common pattern in AWS:
- TLS terminated at ALB (port 443)
- Certificate managed by ACM (AWS Certificate Manager)
- Internal traffic to app can be HTTP or HTTPS based on security requirement

Best practice:
- Redirect HTTP (80) to HTTPS (443)
- Use strong TLS policies
- Renew and rotate certs automatically (ACM helps)

---

## 12) Ports You Should Know

- `22` = SSH
- `80` = HTTP
- `443` = HTTPS
- `3306` = MySQL
- `5432` = PostgreSQL

Never expose DB ports publicly unless absolutely required (and even then, tightly restricted).

---

## 13) Terraform Mapping (Concept -> Resource)

Common AWS Terraform resources:
- VPC -> `aws_vpc`
- Subnet -> `aws_subnet`
- Internet Gateway -> `aws_internet_gateway`
- Route table -> `aws_route_table`, `aws_route_table_association`, `aws_route`
- NAT Gateway -> `aws_nat_gateway` (+ `aws_eip`)
- Security Group -> `aws_security_group`
- NACL -> `aws_network_acl`

---

## 14) Beginner-Friendly Reference Architecture

A safe default architecture:
1. One VPC (`10.0.0.0/16`)
2. Two public subnets (different AZs) for ALB + NAT
3. Two private app subnets (different AZs)
4. Two private DB subnets (different AZs)
5. IGW attached to VPC
6. Public route table: `0.0.0.0/0 -> IGW`
7. Private app route table: `0.0.0.0/0 -> NAT`
8. DB subnet route table: no direct internet route
9. Strict SG rules between layers

This gives high availability, layered security, and controlled internet exposure.

---

## 15) Common Beginner Mistakes

1. Creating “private subnet” but still attaching public IPs
2. Forgetting route table associations
3. Opening `0.0.0.0/0` for SSH in SG
4. Assuming SG alone gives internet access (you still need routes + IGW/NAT)
5. Putting database in public subnet without reason
6. Ignoring IPv6 behavior in dual-stack environments

---

## 16) Quick Mental Model

To debug connectivity, always check in this order:
1. DNS name/IP resolution
2. Route table path
3. IGW/NAT presence
4. Security Group rules
5. NACL rules
6. Host firewall / service listening port

If all six align, traffic usually works.

