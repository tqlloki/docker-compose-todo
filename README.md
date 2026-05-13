# Project: Docker Compose Todo API 🚀

Project này dùng để thực hành chạy một ứng dụng **multi-container** bằng Docker Compose theo hướng production.

Stack chính:

```text
Node.js Express API
MongoDB database
Docker Compose
Terraform tạo VPS
Ansible cài Docker
GitHub Actions CI/CD
Nginx reverse proxy bonus
```

---

## 🔗 Quy trình kết nối hệ thống

### Bước 1: Chuẩn bị code app

Project nằm tại:

```text
/home/ubuntu/workspace/docker-compose-todo
```

API có các endpoint:

```http
GET    /health
GET    /todos
POST   /todos
GET    /todos/:id
PUT    /todos/:id
DELETE /todos/:id
```

Chạy local bằng Docker Compose:

```bash
cd /home/ubuntu/workspace/docker-compose-todo
cp .env.example .env
docker compose up --build
```

Test nhanh:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/todos
```

Tạo todo:

```bash
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Hoc Docker Compose","completed":false}'
```

---

### Bước 2: Chuẩn bị "đất" — tạo VPS bằng Terraform

Anh dùng Terraform tại:

```text
/home/ubuntu/workspace/terraform/create_vps_openstack
```

Chọn OS trong `terraform.tfvars`, ví dụ:

```hcl
os_choice = "ubuntu_22_04"
```

Khuyến nghị OS:

```text
Docker / Node.js / MongoDB / n8n / NocoDB → ubuntu_22_04
DirectAdmin / RHEL-like stack             → almalinux_8
Server nhẹ, ổn định                       → debian_11
Windows app / RDP / IIS                   → windows_2022
Windows legacy                            → windows_2019
```

Chạy:

```bash
cd /home/ubuntu/workspace/terraform/create_vps_openstack
terraform init
terraform plan
terraform apply
```

Sau khi apply xong, copy IP VPS ở output:

```text
vm-ip
```

---

### Bước 3: Lắp "nội thất" — cài Docker bằng Ansible

Anh dùng Ansible chung tại:

```text
/home/ubuntu/workspace/ansible
```

Playbook Docker:

```text
/home/ubuntu/workspace/ansible/playbooks/docker/install_docker.yml
```

Chạy:

```bash
cd /home/ubuntu/workspace/ansible

ansible-playbook playbooks/docker/install_docker.yml \
  -i '<IP_VPS>,' \
  -u root \
  --private-key ~/.ssh/id_rsa \
  -e "ansible_port=2018"
```

Nếu SSH VPS dùng port mặc định 22:

```bash
ansible-playbook playbooks/docker/install_docker.yml \
  -i '<IP_VPS>,' \
  -u root \
  --private-key ~/.ssh/id_rsa \
  -e "ansible_port=22"
```

Kết quả mong muốn trên VPS:

```bash
docker --version
docker compose version
```

---

### Bước 4: Tạo repo GitHub

Anh cần tạo repo GitHub vì bài yêu cầu CI/CD bằng GitHub Actions.

Ví dụ repo:

```text
docker-compose-todo
```

Push code:

```bash
cd /home/ubuntu/workspace/docker-compose-todo

git branch -M main
git remote add origin git@github.com:YOUR_USERNAME/docker-compose-todo.git

git add .
git commit -m "Initial Docker Compose Todo API"
git push -u origin main
```

Nếu remote đã tồn tại:

```bash
git remote -v
git remote set-url origin git@github.com:YOUR_USERNAME/docker-compose-todo.git
```

---

### Bước 5: Nạp thông tin mật lên GitHub

Vào GitHub repo:

```text
Settings → Secrets and variables → Actions → New repository secret
```

Thêm các biến:

```text
DOCKER_USERNAME      Docker Hub username
DOCKER_PASSWORD      Docker Hub token/password
REMOTE_HOST          IP VPS lấy từ Terraform output vm-ip
REMOTE_USER          root hoặc user SSH
REMOTE_PORT          port SSH, ví dụ 2018 hoặc 22
SSH_PRIVATE_KEY      private key dùng SSH vào VPS
DOMAIN               domain/subdomain trỏ về VPS, ví dụ todo.example.com
LETSENCRYPT_EMAIL    email dùng đăng ký Let's Encrypt
```

Trong bài tập này `.env` không có secret, nên GitHub Actions sẽ tự tạo trên VPS:

```env
NODE_ENV=production
MONGO_URI=mongodb://mongo:27017/todoapp
DOMAIN=todo.example.com
LETSENCRYPT_EMAIL=admin@example.com
IMAGE_NAME=<image-vua-build>
```

Sau này nếu thêm password MongoDB, JWT secret, API key... thì lúc đó mới chuyển `.env` sang GitHub Secret.

Docker image sẽ được push lên:

```text
DOCKER_USERNAME/docker-compose-todo
```

Khuyến nghị: tạo sẵn repo `docker-compose-todo` trên Docker Hub, để public cho dễ pull từ VPS.

---

### Bước 6: CI/CD tự deploy

Workflow nằm tại:

```text
.github/workflows/deploy.yml
```

Luồng hoạt động:

```text
push main
→ GitHub Actions checkout code
→ Login Docker Hub
→ Build API image
→ Push image lên Docker Hub
→ SSH vào VPS
→ Upload deploy/docker-compose.prod.yml lên /opt/todo-api
→ Tạo .env production trên VPS
→ Ghi IMAGE_NAME bằng image vừa build
→ docker compose pull
→ docker compose up -d
→ nginx-proxy nhận domain
→ acme-companion tự cấp SSL Let's Encrypt
```

Project cũ `node-docker-deploy` dùng:

```text
SSH VPS → docker run
```

Project này đổi thành:

```text
SSH VPS → docker compose up -d
```

Lý do: app hiện tại có nhiều container:

```text
api + mongo
```

File compose production:

```text
deploy/docker-compose.prod.yml
```

Trên VPS, CI/CD sẽ đặt tại:

```text
/opt/todo-api/docker-compose.prod.yml
/opt/todo-api/.env
```

---

## 🔄 Luồng hoạt động khi sửa code

1. Anh sửa code, ví dụ `src/controllers/todo.controller.js`.
2. Commit và push:

```bash
cd /home/ubuntu/workspace/docker-compose-todo

git add .
git commit -m "Update todo API"
git push origin main
```

3. GitHub Actions tự chạy:

```text
Build image mới
Push lên Docker Hub
SSH vào VPS
Pull image mới
Restart stack bằng Docker Compose
```

4. Kiểm tra:

```bash
curl http://<IP_VPS>:3000/health
curl http://<IP_VPS>:3000/todos
```

---

## 🧪 Test API bằng curl

Health check:

```bash
curl http://localhost:3000/health
```

Tạo todo:

```bash
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Hoc Docker Compose","completed":false}'
```

Lấy danh sách:

```bash
curl http://localhost:3000/todos
```

Lấy chi tiết, cập nhật, xóa:

```bash
TODO_ID="paste_id_o_day"

curl http://localhost:3000/todos/$TODO_ID

curl -X PUT http://localhost:3000/todos/$TODO_ID \
  -H "Content-Type: application/json" \
  -d '{"title":"Hoc Docker Compose production practice","completed":true}'

curl -X DELETE http://localhost:3000/todos/$TODO_ID
```

---

## 🧱 File quan trọng

```text
src/                         Express API + Mongoose model
Dockerfile                   Build production image cho API
docker-compose.yml           Local: API + MongoDB + volume persistent
docker-compose.dev.yml       Local dev mode với nodemon
deploy/docker-compose.prod.yml Production compose dùng image Docker Hub
deploy/nginx/                Reverse proxy Nginx bonus
.github/workflows/deploy.yml CI/CD build + push + deploy
infra/ansible/               Ansible mẫu trong project
infra/terraform/             Terraform mẫu trong project
```

Workspace thật anh đang dùng:

```text
Ansible chung:   /home/ubuntu/workspace/ansible
Terraform chung: /home/ubuntu/workspace/terraform/create_vps_openstack
Project app:     /home/ubuntu/workspace/docker-compose-todo
```

---


## 🔐 Nginx Docker + SSL miễn phí

Production compose đã tích hợp sẵn:

```text
nginxproxy/nginx-proxy
nginxproxy/acme-companion
```

Luồng:

```text
https://DOMAIN
  ↓
nginx-proxy container :443
  ↓
todo-api container :3000
  ↓
todo-mongo container
```

Điều kiện để SSL tự cấp thành công:

1. Domain/subdomain phải trỏ A record về IP VPS.
2. Port `80` và `443` trên VPS phải mở.
3. Không có Nginx/Apache/service khác chiếm port `80/443` trên VPS.
4. GitHub Secrets phải có:

```text
DOMAIN
LETSENCRYPT_EMAIL
```

Kiểm tra trên VPS:

```bash
cd /opt/todo-api
docker compose -f docker-compose.prod.yml ps
docker logs nginx-proxy-acme --tail=100
docker logs nginx-proxy --tail=100
```

SSL lần đầu có thể mất 1-3 phút.

## 🌐 Bonus: Nginx reverse proxy

Nếu muốn truy cập bằng domain thay vì:

```text
http://<IP_VPS>:3000
```

Thì dùng Nginx reverse proxy để đi qua port 80:

```text
http://your-domain.com
```

Ví dụ có sẵn trong:

```text
deploy/nginx/
```

Luồng:

```text
domain.com → nginx container → api:3000
```

---

## Ghi chú an toàn

Không commit các thông tin sau vào Git:

```text
Docker Hub token
SSH private key
OpenStack password
Cloudflare token
Production .env nếu chứa password/token
```

Các giá trị đó đưa vào:

```text
GitHub Actions Secrets
terraform.tfvars local
Ansible Vault nếu cần
```

---

## 🚚 Migrate production sang VPS mới

Khi đổi production từ VPS A sang VPS B, cần nhớ 2 phần khác nhau:

```text
App image/config → deploy lại được bằng GitHub Actions
MongoDB data     → phải backup/restore nếu dùng MongoDB local trong Docker volume
```

### Trường hợp không cần giữ data cũ

Nếu đây chỉ là bài tập/test và không cần dữ liệu cũ:

1. Tạo VPS B bằng Terraform.
2. Cài Docker trên VPS B bằng Ansible.
3. Sửa GitHub Secret:

```text
REMOTE_HOST=<IP_VPS_B>
```

4. Trỏ DNS `DOMAIN` về IP VPS B.
5. Re-run GitHub Actions hoặc push commit mới.

GitHub Actions sẽ deploy lại stack lên VPS B.

---

### Trường hợp cần giữ data MongoDB

Vì MongoDB hiện chạy trong Docker volume local:

```text
VPS A: todo-api_mongo_data
VPS B: todo-api_mongo_data
```

nên data không tự đi theo VPS mới. Cần backup từ VPS A rồi restore sang VPS B.

#### 1. Backup MongoDB trên VPS A

SSH vào VPS A:

```bash
ssh -p 2018 root@<IP_VPS_A>
```

Backup:

```bash
cd /opt/todo-api

docker exec todo-mongo mongodump --archive=/tmp/todo-mongo.archive
docker cp todo-mongo:/tmp/todo-mongo.archive /tmp/todo-mongo.archive
```

Kiểm tra file:

```bash
ls -lh /tmp/todo-mongo.archive
```

#### 2. Copy file backup từ VPS A sang máy local

Trên máy local/dev:

```bash
scp -P 2018 root@<IP_VPS_A>:/tmp/todo-mongo.archive ./todo-mongo.archive
```

Nếu SSH dùng port 22:

```bash
scp root@<IP_VPS_A>:/tmp/todo-mongo.archive ./todo-mongo.archive
```

#### 3. Copy file backup sang VPS B

```bash
scp -P 2018 ./todo-mongo.archive root@<IP_VPS_B>:/tmp/todo-mongo.archive
```

Nếu SSH dùng port 22:

```bash
scp ./todo-mongo.archive root@<IP_VPS_B>:/tmp/todo-mongo.archive
```

#### 4. Restore MongoDB trên VPS B

Đảm bảo stack trên VPS B đã chạy ít nhất một lần để có container `todo-mongo`:

```bash
ssh -p 2018 root@<IP_VPS_B>
cd /opt/todo-api

docker compose -f docker-compose.prod.yml up -d mongo
```

Restore:

```bash
docker cp /tmp/todo-mongo.archive todo-mongo:/tmp/todo-mongo.archive
docker exec todo-mongo mongorestore --drop --archive=/tmp/todo-mongo.archive
```

Sau đó start toàn bộ stack:

```bash
docker compose -f docker-compose.prod.yml up -d
```

Kiểm tra:

```bash
docker compose -f docker-compose.prod.yml ps
curl https://<DOMAIN>/todos
```

---

### Script migrate nhanh

Có thể tạo file local:

```text
scripts/migrate-mongo.sh
```

Nội dung:

```bash
#!/usr/bin/env bash
set -euo pipefail

OLD_HOST="${1:?Missing old VPS IP}"
NEW_HOST="${2:?Missing new VPS IP}"
SSH_PORT="${3:-22}"
ARCHIVE="todo-mongo-$(date +%Y%m%d-%H%M%S).archive"

ssh -p "$SSH_PORT" root@"$OLD_HOST" "
  cd /opt/todo-api
  docker exec todo-mongo mongodump --archive=/tmp/$ARCHIVE
  docker cp todo-mongo:/tmp/$ARCHIVE /tmp/$ARCHIVE
"

scp -P "$SSH_PORT" root@"$OLD_HOST":/tmp/$ARCHIVE /tmp/$ARCHIVE
scp -P "$SSH_PORT" /tmp/$ARCHIVE root@"$NEW_HOST":/tmp/$ARCHIVE

ssh -p "$SSH_PORT" root@"$NEW_HOST" "
  cd /opt/todo-api
  docker compose -f docker-compose.prod.yml up -d mongo
  docker cp /tmp/$ARCHIVE todo-mongo:/tmp/$ARCHIVE
  docker exec todo-mongo mongorestore --drop --archive=/tmp/$ARCHIVE
  docker compose -f docker-compose.prod.yml up -d
"

echo "Migration finished: $OLD_HOST → $NEW_HOST"
```

Chạy:

```bash
chmod +x scripts/migrate-mongo.sh
./scripts/migrate-mongo.sh <IP_VPS_A> <IP_VPS_B> 2018
```

---

### Cách production sạch hơn

Nếu không muốn phải migrate data mỗi lần đổi VPS, nên tách database ra khỏi VPS app:

```text
VPS App A/B: api + nginx
DB riêng: MongoDB Atlas / Managed MongoDB / VPS DB riêng
```

Khi đó đổi VPS chỉ cần:

```text
1. Cài Docker trên VPS mới
2. Đổi REMOTE_HOST trong GitHub Secrets
3. Đổi DNS DOMAIN sang IP mới
4. Re-run GitHub Actions
```

Data nằm ở DB riêng nên không cần backup/restore giữa VPS app.

---

## 🕛 Scheduled MongoDB backup lên Cloudflare R2

Bài backup dùng database MongoDB của project này và upload backup lên Cloudflare R2 mỗi 12 giờ.

### Luồng hoạt động

```text
GitHub Actions schedule mỗi 12 giờ
  ↓ SSH vào VPS
Upload script backup
  ↓
docker exec todo-mongo mongodump
  ↓
Nén thành .tar.gz
  ↓
Upload lên Cloudflare R2 bằng aws-cli S3-compatible endpoint
```

### File đã chuẩn bị

```text
.github/workflows/backup-mongo-r2.yml
scripts/backup-mongo-to-r2.sh
scripts/restore-latest-mongo-from-r2.sh
```

### Tạo R2 bucket bằng Terraform

Trong Terraform chung:

```text
/home/ubuntu/workspace/terraform/create_vps_openstack
```

đã có resource:

```hcl
resource "cloudflare_r2_bucket" "backup_storage" {
  account_id    = var.cloudflare_account_id
  name          = var.r2_backup_bucket_name
  location      = var.r2_backup_bucket_location
  storage_class = var.r2_backup_bucket_storage_class
}
```

Cấu hình trong `terraform.tfvars`:

```hcl
r2_backup_bucket_name = "todo-mongo-backups"
r2_backup_bucket_location = "APAC"
r2_backup_bucket_storage_class = "Standard"
```

Chạy:

```bash
cd /home/ubuntu/workspace/terraform/create_vps_openstack
terraform plan
terraform apply
```

### Tạo R2 access key

Trong Cloudflare Dashboard:

```text
R2 → Manage R2 API Tokens → Create API token
```

Quyền cần có:

```text
Object Read & Write
```

Giới hạn vào bucket backup nếu Cloudflare cho chọn scope bucket.

### GitHub Secrets cần thêm

Ngoài các secret deploy cũ, thêm:

```text
R2_BUCKET              tên bucket, ví dụ todo-mongo-backups
R2_ACCOUNT_ID          Cloudflare Account ID
R2_ACCESS_KEY_ID       R2 Access Key ID
R2_SECRET_ACCESS_KEY   R2 Secret Access Key
```

Workflow backup vẫn dùng các secret SSH cũ:

```text
REMOTE_HOST
REMOTE_USER
REMOTE_PORT
SSH_PRIVATE_KEY
```

### Chạy backup thủ công

Vào GitHub repo:

```text
Actions → Backup MongoDB to Cloudflare R2 → Run workflow
```

Hoặc trên VPS, nếu đã có script:

```bash
cd /opt/todo-api

R2_BUCKET="todo-mongo-backups" \
R2_ACCOUNT_ID="<account_id>" \
R2_ACCESS_KEY_ID="<access_key>" \
R2_SECRET_ACCESS_KEY="<secret_key>" \
./backup-mongo-to-r2.sh
```

### Lịch backup

Workflow chạy mỗi 12 giờ theo UTC:

```yaml
- cron: "0 */12 * * *"
```

Tức là khoảng:

```text
00:00 UTC và 12:00 UTC
07:00 và 19:00 giờ Việt Nam
```

### Kiểm tra backup trên R2

Backup sẽ nằm trong prefix:

```text
mongodb/
```

Tên file dạng:

```text
todo-mongo-20260512T120000Z.archive.tar.gz
```

### Restore latest backup từ R2

Upload script restore lên VPS nếu cần:

```bash
scp -P 2018 scripts/restore-latest-mongo-from-r2.sh root@<IP_VPS>:/opt/todo-api/
```

SSH vào VPS:

```bash
ssh -p 2018 root@<IP_VPS>
cd /opt/todo-api
chmod +x restore-latest-mongo-from-r2.sh
```

Restore bản mới nhất:

```bash
R2_BUCKET="todo-mongo-backups" \
R2_ACCOUNT_ID="<account_id>" \
R2_ACCESS_KEY_ID="<access_key>" \
R2_SECRET_ACCESS_KEY="<secret_key>" \
./restore-latest-mongo-from-r2.sh
```

Script sẽ:

```text
1. Tìm file backup mới nhất trong R2 prefix mongodb/
2. Download về VPS
3. Giải nén .tar.gz
4. docker cp archive vào todo-mongo
5. mongorestore --drop
```

Lưu ý: `mongorestore --drop` sẽ xóa collection hiện tại rồi restore từ backup.

---

## 🔵🟢 Blue-Green deployment

Project này đã được nâng từ deploy một container API sang mô hình blue-green.

### Ý tưởng

Luôn có 2 slot API:

```text
api-blue   → container todo-api-blue
api-green  → container todo-api-green
```

Tại một thời điểm chỉ một slot nhận domain production:

```text
DOMAIN → nginx-proxy → active slot
```

Slot còn lại là inactive, dùng để deploy version mới trước. Sau khi healthcheck OK mới switch traffic.

### Luồng deploy

```text
GitHub Actions build image mới
  ↓
Push Docker Hub với tag commit SHA
  ↓
SSH vào VPS
  ↓
Đọc slot đang active từ /opt/todo-api/.active-slot
  ↓
Deploy image mới vào slot inactive
  ↓
Healthcheck http://127.0.0.1:3000/health bên trong container inactive
  ↓
Nếu OK: gán DOMAIN sang slot mới
  ↓
nginx-proxy tự reload và chuyển traffic
```

Nếu healthcheck fail:

```text
Traffic vẫn ở slot cũ
Deploy fail
Log container mới được in ra để debug
```

### File liên quan

```text
deploy/docker-compose.prod.yml
scripts/blue-green-deploy.sh
scripts/blue-green-rollback.sh
.github/workflows/deploy.yml
```

### Production compose hiện có

```text
nginx-proxy
acme-companion
api-blue
api-green
mongo
```

MongoDB vẫn chỉ có một service dùng chung:

```text
todo-mongo
```

Nên blue-green chỉ áp dụng cho app API, không nhân đôi database.

### State active slot

Trên VPS, slot đang active được lưu ở:

```text
/opt/todo-api/.active-slot
```

Nội dung là:

```text
blue
```

hoặc:

```text
green
```

Kiểm tra:

```bash
cd /opt/todo-api
cat .active-slot
docker compose -f docker-compose.prod.yml ps
```

### Rollback thủ công

Nếu bản mới có lỗi sau khi đã switch traffic, rollback về slot còn lại:

```bash
cd /opt/todo-api

DOMAIN="todo.example.com" \
LETSENCRYPT_EMAIL="admin@example.com" \
./blue-green-rollback.sh
```

Thay `DOMAIN` và `LETSENCRYPT_EMAIL` bằng giá trị thật.

Rollback này không rebuild image. Nó chỉ chuyển domain từ slot hiện tại sang slot còn lại.

### Kiểm tra image mỗi slot

```bash
docker inspect todo-api-blue --format '{{.Config.Image}}'
docker inspect todo-api-green --format '{{.Config.Image}}'
```

### Kiểm tra log

```bash
docker logs todo-api-blue --tail=100
docker logs todo-api-green --tail=100
docker logs nginx-proxy --tail=100
docker logs nginx-proxy-acme --tail=100
```

### Lưu ý về database migration

Blue-green giúp giảm downtime cho app container, nhưng không tự giải quyết schema migration phức tạp.

Nguyên tắc an toàn:

```text
1. Migration DB phải backward-compatible.
2. App version cũ và mới nên cùng đọc được schema trong giai đoạn chuyển traffic.
3. Không chạy migration phá schema trước khi chắc chắn rollback không cần nữa.
```

Với todo API hiện tại chưa có migration schema phức tạp, nên ổn.
