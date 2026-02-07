.PHONY: dev deploy deploy-staging setup-domain clean

dev:
	cd ~/workspace/fitforce_web && python3 -m http.server 8000

deploy:
	./deploy.sh prod

deploy-staging:
	./deploy.sh staging

setup-domain:
	@read -p "Enter domain (e.g., fitforce.com): " domain; \
	./setup-domain.sh $$domain prod

clean:
	rm -rf .aws-sam
