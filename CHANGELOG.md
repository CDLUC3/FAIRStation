# Changelog

## [1.1.0](https://github.com/CDLUC3/FAIRStation/compare/v1.0.0...v1.1.0) (2026-11-25)


### Features

* add ResearchActivity, Person, and ActivityPerson models ([#69](https://github.com/CDLUC3/FAIRStation/issues/69)) ([e85bce6](https://github.com/CDLUC3/FAIRStation/commit/e85bce6e4d36ac6c91e28e62aabfcb51030b7124))
* add Station model and Quail Ridge seed ([#66](https://github.com/CDLUC3/FAIRStation/issues/66)) ([47d0ad8](https://github.com/CDLUC3/FAIRStation/commit/47d0ad895ad8fc111a4e486426197e8516fcab7b))
* **imports:** define source inputs and RAMS translation ([#73](https://github.com/CDLUC3/FAIRStation/issues/73)) ([96a1670](https://github.com/CDLUC3/FAIRStation/commit/96a16706e31276cb6ad8f226517fbcd20974e58d))
* **imports:** persist batches with explicit identity policy ([#80](https://github.com/CDLUC3/FAIRStation/issues/80)) ([ee89cfe](https://github.com/CDLUC3/FAIRStation/commit/ee89cfe72fd777dbb6580b9c565aa768ada69e81))
* **rams:** add development import and local source archive ([#81](https://github.com/CDLUC3/FAIRStation/issues/81)) ([28c4287](https://github.com/CDLUC3/FAIRStation/commit/28c4287e4e569b982eef91b25aa2852c48e1175e))
* **rams:** add paginated read-only API client ([#72](https://github.com/CDLUC3/FAIRStation/issues/72)) ([eba0a27](https://github.com/CDLUC3/FAIRStation/commit/eba0a27ec510a0101fef7a900cbf4bcb725bb2dd))
* **rams:** import project owners and applicants as roles ([#92](https://github.com/CDLUC3/FAIRStation/issues/92)) ([512dce3](https://github.com/CDLUC3/FAIRStation/commit/512dce3063235266d8475fa8523caf1bc650515c))
* **rams:** preserve project member affiliations ([#88](https://github.com/CDLUC3/FAIRStation/issues/88)) ([1883c9f](https://github.com/CDLUC3/FAIRStation/commit/1883c9f88c43dd59cec50c1ff7a4b0969046cb22))


### Documentation

* **imports:** visualize reserve-based import flow ([#86](https://github.com/CDLUC3/FAIRStation/issues/86)) ([af1bcf4](https://github.com/CDLUC3/FAIRStation/commit/af1bcf43c29425aab8f3880624554b9529721713))
* improve the pull request template ([#75](https://github.com/CDLUC3/FAIRStation/issues/75)) ([bd9952c](https://github.com/CDLUC3/FAIRStation/commit/bd9952ce6e3fa01e95eee83e804afdbbae036fec))


### Miscellaneous

* **rubocop:** set method and class length limits ([#90](https://github.com/CDLUC3/FAIRStation/issues/90)) ([6e4e6a4](https://github.com/CDLUC3/FAIRStation/commit/6e4e6a49b2885d98ef2ece5a9b805fb0b6f6c385))


### Code Refactoring

* **imports:** simplify import code and split tests ([#91](https://github.com/CDLUC3/FAIRStation/issues/91)) ([bb40b28](https://github.com/CDLUC3/FAIRStation/commit/bb40b28405920feaf90d9c19312d45fc7cb7d9e0))

## 1.0.0 (2026-11-05)


### Features

* add the development and release workflow ([285243d](https://github.com/CDLUC3/FAIRStation/commit/285243db6516d833c21623d7876560f6b5712c4a))
* add the release workflow and secrets policy ([3a7f5e3](https://github.com/CDLUC3/FAIRStation/commit/3a7f5e3f9f4b76ae6232e06ed447001cd6e8b490))
* **observability:** report production exceptions with Honeybadger ([#59](https://github.com/CDLUC3/FAIRStation/issues/59)) ([707c43e](https://github.com/CDLUC3/FAIRStation/commit/707c43e0f37ba89522446948e05ded848d7e7231))


### Documentation

* keep only the master key in deployment ([f3cc080](https://github.com/CDLUC3/FAIRStation/commit/f3cc0809261f5cda8af62cfc23fe19e464c8ceb9))
* keep release token out of Rails credentials ([0dc5805](https://github.com/CDLUC3/FAIRStation/commit/0dc58056fb3e58ee16ae8d7e18ce72b074cd29a3))
* make the first promotion a merge commit ([e7e2aca](https://github.com/CDLUC3/FAIRStation/commit/e7e2aca43748586839ab1d4f5802c9c806314664))
* note the hotfix path in the release runbook ([b41e9b3](https://github.com/CDLUC3/FAIRStation/commit/b41e9b3679864d02678758a9570146ad6062e72e))


### Miscellaneous

* centralize application secrets in Rails credentials ([72d2d46](https://github.com/CDLUC3/FAIRStation/commit/72d2d466b39ca3bb406087d57c06f31141449f27))
* update security dependencies ([#67](https://github.com/CDLUC3/FAIRStation/issues/67)) ([e66be05](https://github.com/CDLUC3/FAIRStation/commit/e66be05fcacfe256257839d9f804d06b51033eca))
