# git_environment
#
# Ce script permet de renseigner automatiquement les variables suivantes via Kerberos :
# GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME, GIT_COMMITTER_EMAIL
# Elles sont utilisées par "git commit".
# Ainsi, c'est l'identité de l'utilisateur réel qui est insérée dans l'historique.
# Il devient inutile d'utiliser "git config user.name" et "git config user.email".
# Cela est très pratique pour mettre à jour les dépôts stockés sur des comptes applicatifs
# qui sont modifiés par plusieurs développeurs.
#
# L'identité Kerberos de l'utilisateur n'est récupérable que si :
# - le ticket est forwardable (obtenu avec kinit -f)
# - le ticket a été forwardé (connexion avec ssh -K)
#
# Ce fichier doit être sourcé (et non exécuté) depuis un shell
# pour qu'il puisse définir les variables d'environnement,
# par exemple, avec ". git_environment"
# ou automatiquement en installant ce fichier dans /etc/profile.d
# C'est pour cela qu'il n'y a pas de shebang, et que ce script n'a pas le flag x.
# De plus la syntaxe doit être compatible avec /bin/sh pour qu'il fonctionne quel que soit le shell.
# Les variables et fonctions utilisées ne doivent pas causer de conflit avec l'environnement,
# donc et elles doivent être détruites en sortie.

# Extraire la valeur d'un seul attribut
# $1 = bloc d'attributs
# $2 = nom de l'attribut
tmp_ldap_attribute ()
{
  LIGNE=$(echo "$1" |grep ^$2:)

  # Si une valeur contient un caractère non-ASCII,
  # alors elle est encodée en MD5 et le séparateteur entre le nom et la valeur est "::".
  MD5=$(echo "$LIGNE" |sed -n 's/[^:]*:: \(.*\)/\1/p')

  if [ -n "$MD5" ]
  then
    echo "$MD5" |base64 --decode -i
  else
    echo "$LIGNE" |sed -n 's/[^:]*: \(.*\)/\1/p'
  fi
}

# Utiliser une fonction main pour que les variables locales soient automatiquement détruites
tmp_main ()
{
  # Récupérer l'identité de l'utilisateur connecté via Kerberos
  # Ceci n'est possible que si :
  # - le ticket est forwardable (obtenu avec kinit -f)
  # - le ticket a été forwardé (connexion avec ssh -K)
  KPRINCIPAL=$(klist 2>/dev/null |sed -n 's/.*rincipal: \([^@]*\).*/\1/p')

  # Ne rien faire si l'utilisateur réel n'a pas pu être détecté
  if [ -z "$KPRINCIPAL" ]
  then
    return
  fi

  # Récupérer les attributs LDAP de l'utilisateur
  # Idéalement, les variables URI et BASE doivent être configurées dans le fichier /etc/ldap/ldap.conf
  # Dans le cas contraire, il faut ajouter les options suivantes sur la ligne de commande de ldapsearch :
  # -h ldap.universite.fr
  # -b ou=people,dc=universite,dc=fr
  LDAP_ATTRIBUTES=$(ldapsearch -x -LLL uid="$KPRINCIPAL" displayName mail)

  # Définir les variables qui seront utilisées par "git commit"
  export GIT_AUTHOR_NAME=$(tmp_ldap_attribute "$LDAP_ATTRIBUTES" displayName)
  export GIT_AUTHOR_EMAIL=$(tmp_ldap_attribute "$LDAP_ATTRIBUTES" mail)
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
  export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
}

# Appeler la fonction principale
tmp_main

# Nettoyer l'environnement
unset tmp_ldap_attribute
unset tmp_main
