.PHONY: dev deploy deploy-staging clean

dev:
	cd ~/workspace/fitforce_web && python3 -m http.server 8000

deploy:
	./deploy.sh prod

deploy-staging:
	./deploy.sh staging

clean:
	rm -rf .aws-sam
