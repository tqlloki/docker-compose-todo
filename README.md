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
```

Trong bài tập này `.env` không có secret, nên GitHub Actions sẽ tự tạo trên VPS:

```env
NODE_ENV=production
APP_PORT=3000
MONGO_URI=mongodb://mongo:27017/todoapp
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
