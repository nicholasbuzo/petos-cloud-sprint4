-- Evidência de CRUD no PostgreSQL da Azure (banco petosdb).
-- Execute depois de cada operação feita pela aplicação, conforme o roteiro do README.

-- Usuário e pet usados na demonstração
SELECT id, name, email, role FROM users ORDER BY id DESC LIMIT 5;
SELECT id, name, species, tutor_name, active FROM pets ORDER BY id DESC LIMIT 5;

-- CREATE: a nova rotina aparece | UPDATE: a descrição muda | DELETE: a rotina some
SELECT * FROM routine_records ORDER BY id DESC LIMIT 5;
