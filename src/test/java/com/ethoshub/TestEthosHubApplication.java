package com.ethoshub;

import org.springframework.boot.SpringApplication;

public class TestEthosHubApplication {

	public static void main(String[] args) {
		SpringApplication.from(EthosHubApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
