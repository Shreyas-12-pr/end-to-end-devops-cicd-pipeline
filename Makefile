.PHONY: test package image local-up local-down verify

test:
	mvn -B -ntp clean test

package:
	mvn -B -ntp package -DskipTests

image: package
	docker build --pull -t end-to-end-devops-app:local .

local-up:
	docker compose up -d --build

local-down:
	docker compose down

verify:
	./scripts/verify-local.sh
