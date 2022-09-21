run:
	docker compose rm publisher subscriber subscriber14 && docker compose up --build publisher subscriber subscriber14

.PHONY: run
