env = "staging"

# How many pre-started containers the node may hold. Prod holds none.
spares_per_node = "16"

# Allow to replicate app docker images to these accounts
ecr_replication_targets = [
  {
    "account_id" = "274425519734",
    "region"     = "eu-central-1"
  }
]
