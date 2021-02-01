terraform {
    required_version = ">=0.12.0"
    //On se créé une sauvegarde de state, cela nous permettra de pouvoir faire un rollback vers le state précédent en cas de problème
    backend "s3" {
        region = "us-east-1"
        profile =  "default"
        key = "terraformstatefichier"
        bucket = "pourpourpourpourpour"
    }
}