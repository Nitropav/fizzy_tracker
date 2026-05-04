class AddPayloadToGithubWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :github_webhook_deliveries, :payload, :json, null: false, default: {}
  end
end
