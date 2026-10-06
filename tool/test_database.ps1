param([string]$ContainerName = 'petloop-permission-tests')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ($ContainerName -notmatch '^petloop-permission-tests[-a-z0-9]*$') { throw 'Only a PetLoop test container is allowed.' }
$existing = docker ps -a --filter "name=^/$ContainerName$" --format '{{.Names}}'
if ($existing) { throw "Test container already exists: $ContainerName. Use a fresh test name." }
$schemaPath = Join-Path $projectRoot 'supabase'
docker run --detach --name $ContainerName --label petloop.purpose=permission-tests --env POSTGRES_PASSWORD=local-test-only --mount "type=bind,source=$schemaPath,target=/tests,readonly" postgres:17-alpine
if ($LASTEXITCODE -ne 0) { throw 'Could not create isolated PostgreSQL container.' }
for ($attempt = 0; $attempt -lt 30; $attempt++) {
  docker exec $ContainerName pg_isready --username postgres | Out-Null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Milliseconds 500
}
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/local_schema.sql
if ($LASTEXITCODE -ne 0) { throw 'Fixture failed.' }
foreach ($migration in (Get-ChildItem -LiteralPath "$projectRoot\supabase\migrations" -Filter '*.sql' | Sort-Object Name)) {
  Write-Output "Applying $($migration.Name)"
  docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file "/tests/migrations/$($migration.Name)" --quiet
  if ($LASTEXITCODE -ne 0) { throw "Migration failed: $($migration.Name)" }
}
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/feature_access_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Permission behavior tests failed.' }
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/signup_roles_test.sql
if ($LASTEXITCODE -ne 0) { throw 'New-account role protection tests failed.' }
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/account_deletion_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Account deletion tests failed.' }
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/findvet_public_toggle_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Find-a-vet public switch tests failed.' }
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/permission_checks_once_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Once-per-statement permission check tests failed.' }

docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/community_chat_safety_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Community chat and safety tests failed.' }
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/administration_history_test.sql
if ($LASTEXITCODE -ne 0) { throw 'Administration history tests failed.' }
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/history_persistence_write.sql
if ($LASTEXITCODE -ne 0) { throw 'History persistence write failed.' }
docker restart $ContainerName | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not restart test database.' }
for ($attempt = 0; $attempt -lt 30; $attempt++) {
  docker exec $ContainerName pg_isready --username postgres | Out-Null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Milliseconds 500
}
docker exec $ContainerName psql --username postgres --set ON_ERROR_STOP=1 --file /tests/tests/history_persistence_read.sql
if ($LASTEXITCODE -ne 0) { throw 'History did not survive database restart.' }
Write-Output 'PostgreSQL migrations and feature permission tests passed.'
