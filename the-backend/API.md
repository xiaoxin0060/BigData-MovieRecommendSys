# API 接口文档

## 基础信息

- **Base URL**: `http://localhost:3000/api`
- **认证方式**: JWT Token（部分接口需要）
- **认证请求头**: `Authorization: Bearer {token}`

## 统一响应格式

### 成功响应
```json
{
  "success": true,
  "message": "提示信息（可选）",
  "data": { ... }
}
```

### 失败响应
```json
{
  "success": false,
  "message": "错误信息"
}
```

---

## 1. 用户模块 `/api/users`

### 1.1 用户注册
- **接口**: `POST /api/users/register`
- **认证**: 不需要
- **请求体**:
```json
{
  "userAccount": "test@example.com",
  "userPassword": "123456",
  "userName": "张三",
  "gender": 1
}
```
- **响应**:
```json
{
  "success": true,
  "message": "注册成功",
  "data": {
    "id": "1",
    "userAccount": "test@example.com",
    "userName": "张三",
    "gender": 1
  }
}
```

### 1.2 用户登录
- **接口**: `POST /api/users/login`
- **认证**: 不需要
- **请求体**:
```json
{
  "userAccount": "test@example.com",
  "userPassword": "123456"
}
```
- **响应**:
```json
{
  "success": true,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "1",
      "userAccount": "test@example.com",
      "userName": "张三",
      "gender": 1
    }
  }
}
```

### 1.3 获取个人信息
- **接口**: `GET /api/users/profile`
- **认证**: 需要（Bearer Token）
- **响应**:
```json
{
  "success": true,
  "data": {
    "id": "1",
    "userAccount": "test@example.com",
    "userName": "张三",
    "gender": 1
  }
}
```

---

## 2. 电影模块 `/api/movies`

### 2.1 获取电影列表
- **接口**: `GET /api/movies`
- **认证**: 不需要
- **查询参数**:
  - `page`: 页码（默认 1）
  - `pageSize`: 每页数量（默认 20）
  - `genre`: 类型筛选（如：动作、科幻）
  - `year`: 年份筛选
  - `sort`: 排序方式（avgRating | year | title）

- **请求示例**: `GET /api/movies?page=1&pageSize=10&genre=科幻&sort=avgRating`

- **响应**:
```json
{
  "success": true,
  "data": {
    "movies": [
      {
        "id": "1",
        "title": "肖申克的救赎",
        "genres": "剧情|犯罪",
        "year": 1994,
        "posterUrl": "http://...",
        "avgRating": 4.8,
        "ratingCount": 1500
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 10,
      "total": 100,
      "totalPages": 10
    }
  }
}
```

### 2.2 获取电影详情
- **接口**: `GET /api/movies/:id`
- **认证**: 不需要
- **请求示例**: `GET /api/movies/1`
- **响应**:
```json
{
  "success": true,
  "data": {
    "id": "1",
    "title": "肖申克的救赎",
    "genres": "剧情|犯罪",
    "year": 1994,
    "director": "弗兰克·德拉邦特",
    "actors": "蒂姆·罗宾斯|摩根·弗里曼",
    "description": "一个关于希望和自由的故事...",
    "posterUrl": "http://...",
    "avgRating": 4.8,
    "ratingCount": 1500
  }
}
```

---

## 3. 评分模块 `/api/ratings`

### 3.1 用户评分
- **接口**: `POST /api/ratings`
- **认证**: 需要（Bearer Token）
- **请求体**:
```json
{
  "movieId": "1",
  "rating": 4.5
}
```
- **响应**:
```json
{
  "success": true,
  "message": "评分成功",
  "data": {
    "id": "123",
    "movieId": "1",
    "rating": 4.5
  }
}
```

### 3.2 获取我的评分
- **接口**: `GET /api/ratings/my`
- **认证**: 需要（Bearer Token）
- **查询参数**:
  - `page`: 页码
  - `pageSize`: 每页数量

- **响应**:
```json
{
  "success": true,
  "data": {
    "ratings": [
      {
        "id": "123",
        "rating": 4.5,
        "createdAt": "2025-01-10T12:00:00Z",
        "movie": {
          "id": "1",
          "title": "肖申克的救赎",
          "genres": "剧情|犯罪",
          "year": 1994,
          "posterUrl": "http://..."
        }
      }
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 50,
      "totalPages": 3
    }
  }
}
```

### 3.3 获取某部电影的评分
- **接口**: `GET /api/ratings/movie/:movieId`
- **认证**: 不需要
- **请求示例**: `GET /api/ratings/movie/1`
- **响应**:
```json
{
  "success": true,
  "data": {
    "ratings": [
      {
        "id": "123",
        "rating": 4.5,
        "createdAt": "2025-01-10T12:00:00Z",
        "user": {
          "id": "1",
          "userName": "张三"
        }
      }
    ],
    "pagination": { ... }
  }
}
```

---

## 4. 推荐模块 `/api/recommendations`

### 4.1 获取个性化推荐（核心功能）
- **接口**: `GET /api/recommendations/for-me`
- **认证**: 需要（Bearer Token）
- **查询参数**:
  - `limit`: 推荐数量（默认 20）
  - `algorithm`: 算法名称（默认 ALS）

- **响应**:
```json
{
  "success": true,
  "data": {
    "recommendations": [
      {
        "movie": {
          "id": "1",
          "title": "肖申克的救赎",
          "genres": "剧情|犯罪",
          "year": 1994,
          "posterUrl": "http://...",
          "avgRating": 4.8,
          "description": "..."
        },
        "score": 0.95,
        "rank": 1,
        "reason": "基于您的观影偏好推荐（算法：ALS）",
        "updatedAt": "2025-01-10T00:00:00Z"
      }
    ],
    "isPersonalized": true,
    "algorithm": "ALS"
  }
}
```

**说明**:
- 推荐数据由 Spark 离线计算生成，存储在 `recommendation` 表
- 如果用户没有推荐数据，返回热门电影
- `isPersonalized` 字段标识是否为个性化推荐

### 4.2 获取相似电影推荐
- **接口**: `GET /api/recommendations/similar/:movieId`
- **认证**: 不需要
- **查询参数**:
  - `limit`: 推荐数量（默认 10）

- **请求示例**: `GET /api/recommendations/similar/1?limit=5`
- **响应**:
```json
{
  "success": true,
  "data": {
    "baseMovie": {
      "id": "1",
      "title": "肖申克的救赎"
    },
    "similarMovies": [
      {
        "id": "2",
        "title": "霸王别姬",
        "genres": "剧情|爱情",
        "year": 1993,
        "posterUrl": "http://...",
        "avgRating": 4.7,
        "description": "..."
      }
    ]
  }
}
```

---

## 5. 其他接口

### 5.1 健康检查
- **接口**: `GET /api/health`
- **认证**: 不需要
- **响应**:
```json
{
  "success": true,
  "message": "API 服务运行正常",
  "timestamp": "2025-01-10T12:00:00Z"
}
```

---

## 错误码说明

| HTTP 状态码 | 说明 |
|------------|------|
| 200 | 请求成功 |
| 201 | 创建成功 |
| 400 | 请求参数错误 |
| 401 | 未认证或认证失败 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |

---

## 测试说明

### 使用 Postman 测试

1. **注册用户**:
   ```
   POST http://localhost:3000/api/users/register
   Body: { "userAccount": "test@example.com", "userPassword": "123456" }
   ```

2. **登录获取 Token**:
   ```
   POST http://localhost:3000/api/users/login
   Body: { "userAccount": "test@example.com", "userPassword": "123456" }
   复制响应中的 token
   ```

3. **使用 Token 访问受保护接口**:
   ```
   GET http://localhost:3000/api/users/profile
   Headers: Authorization: Bearer {token}
   ```

### 使用 curl 测试

```bash
# 登录
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"userAccount":"test@example.com","userPassword":"123456"}'

# 获取电影列表
curl http://localhost:3000/api/movies?page=1&pageSize=10

# 获取推荐（需要 token）
curl http://localhost:3000/api/recommendations/for-me \
  -H "Authorization: Bearer {token}"
```

---

## 数据库表说明

### 核心表关系

```
user (用户表)
  ↓ 1:N
rating (评分表) ← Spark 输入
  ↓
movie (电影表)
  ↑
recommendation (推荐表) ← Spark 输出
  ↑ N:1
user (用户表)
```

### Spark 对接说明

**Spark 同学需要做的**:
1. 从 `rating` 表读取用户评分数据
2. 运行推荐算法（ALS 协同过滤）
3. 将推荐结果写入 `recommendation` 表

**写入格式**:
```sql
INSERT INTO recommendation (userId, movieId, score, rank, algorithm) 
VALUES (1, 100, 0.95, 1, 'ALS');
```

**更新频率**: 建议每天凌晨运行一次（离线计算）

