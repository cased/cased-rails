# cased-rails

A Cased client for Ruby on Rails applications in your organization to control and monitor the access of information within your organization.

## Overview

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Cased CLI](#cased-cli)
    - [Recording console sessions](#recording-console-sessions)
    - [Approval workflows for sensitive operations](#approval-workflows-for-sensitive-operations)
  - [Audit trails](#audit-trails)
    - [Publishing events to Cased](#publishing-events-to-cased)
    - [Publishing audit events for all record creation, updates, and deletions automatically](#publishing-audit-events-for-all-record-creation-updates-and-deletions-automatically)
    - [Retrieving events from a Cased audit trail](#retrieving-events-from-a-cased-audit-trail)
    - [Retrieving events from multiple Cased audit trails](#retrieving-events-from-multiple-cased-audit-trails)
    - [Exporting events](#exporting-events)
    - [Masking & filtering sensitive information](#masking-and-filtering-sensitive-information)
    - [Disable publishing events](#disable-publishing-events)
    - [Context](#context)
    - [Testing](#testing)
- [Customizing cased-rails](#customizing-cased-rails)
- [Contributing](#contributing)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cased-rails'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cased-rails

## Configuration

All configuration options available in cased-rails are available to be configured by an environment variable or manually.

```ruby
Cased.configure do |config|
  # GUARD_APPLICATION_KEY=guard_application_1ntKX0P4vUbKoc0lMWGiSbrBHcH
  config.guard_application_key = 'guard_application_1ntKX0P4vUbKoc0lMWGiSbrBHcH'

  # GUARD_USER_TOKEN=user_1oFqlROLNRGVLOXJSsHkJiVmylr
  config.guard_user_token = 'user_1oFqlROLNRGVLOXJSsHkJiVmylr'

  # DENY_IF_UNREACHABLE=1
  config.guard_deny_if_unreachable = true

  # Attach metadata to all CLI requests. This metadata will appear in Cased and
  # any notification source such as email or Slack.
  #
  # You are limited to 20 properties and cannot be a nested dictionary. Metadata
  # specified in the CLI request overrides any configured globally.
  config.cli.metadata = {
    rails_env: ENV['RAILS_ENV'],
    heroku_application: ENV['HEROKU_APP_NAME'],
    git_commit: ENV['GIT_COMMIT'],
  }

  # CASED_POLICY_KEY=policy_live_1dQpY5JliYgHSkEntAbMVzuOROh
  config.policy_key = 'policy_live_1dQpY5JliYgHSkEntAbMVzuOROh'

  # CASED_USERS_POLICY_KEY=policy_live_1dQpY8bBgEwdpmdpVrrtDzMX4fH
  # CASED_ORGANIZATIONS_POLICY_KEY=policy_live_1dSHQRurWX8JMYMbkRdfzVoo62d
  config.policy_keys = {
    users: 'policy_live_1dQpY8bBgEwdpmdpVrrtDzMX4fH',
    organizations: 'policy_live_1dSHQRurWX8JMYMbkRdfzVoo62d',
  }

  # CASED_PUBLISH_KEY=publish_live_1dQpY1jKB48kBd3418PjAotmEwA
  config.publish_key = 'publish_live_1dQpY1jKB48kBd3418PjAotmEwA'

  # CASED_PUBLISH_URL=https://publish.cased.com
  config.publish_url = 'https://publish.cased.com'

  # CASED_API_URL=https://api.cased.com
  config.api_url = 'https://api.cased.com'

  # CASED_RAISE_ON_ERRORS=1
  config.raise_on_errors = false

  # CASED_SILENCE=1
  config.silence = false

  # CASED_HTTP_OPEN_TIMEOUT=5
  config.http_open_timeout = 5

  # CASED_HTTP_READ_TIMEOUT=10
  config.http_read_timeout = 10
end
```

## Usage

### Cased CLI

#### Playback console sessions

Having visibility into production terminal sessions is essential to providing
access to sensitive data and critical systems. `cased-rails` can provide complete
command line session recordings with minimal configuration.

First, enable the "Record output" option in your application's settings page on Cased.

Next grab the application's key from the same settings page and configure
`cased-rails` with it either by using an environment variable or manually.

**Environment variable**

```
GUARD_APPLICATION_KEY=guard_application_1rBCh8o3YMaI1eAKxbrNvnLki3x rails console
```

**Manually**

```ruby
Cased.configure do |config|
  config.guard_application_key = 'guard_application_1rBCh8o3YMaI1eAKxbrNvnLki3x'
end
```

By default playback will be saved only when a Rails console is started outside
of development and test. When the playback is being saved, by default all
parameters other than `id`, `action`, and `controller` will be filtered out.
For example:

```
#<User id: "user_1qwkKB8IGxQFlu3C4lI53tCIyZI", organization: "Enterprise">
```

Would become:

```
#<User id: "user_1qwkKB8IGxQFlu3C4lI53tCIyZI", organization: [FILTERED]>
```

If you'd like to configure if filtering is enabled or specify which attributes
are not filtered you can do so with:

```ruby
Cased.configure do |config|
  config.unfiltered_parameters = ['id', 'action', 'controller']
  config.filter_parameters = Rails.env.production?
end
```

#### Approval workflows for sensitive operations

Adding approval workflows to your controllers is a two step process in your
Rails applications. 

First, mount the Rails engine in your routes. The included Rails engine in
cased-rails is necessary for the approval workflow to know whether or not it has
been requested, approved, denied, canceled or timed out.

```ruby
Rails.application.routes.draw do
  mount Cased::Rails::Engine => '/cased'

  root to: 'home#show'
end
```

To control the requirements for an approval workflow, that must be configured
within your CLI application settings on Cased. Some controls include restricting
which users or groups can approve the request, if a reason is required, how long
until the request times out, and more.

To start an your approval workflow all that is needed is to call the `guard`
method before a request using `before_action`.

```ruby
class AccountsController < ApplicationController
  before_action :guard, only: %i[update destroy]

  def update
    if current_account.update(account_params)
      redirect_to current_account
    else
      render :edit
    end
  end

  def destroy
    if current_account.destroy
      redirect_to accounts_path
    else
      redirect_to current_account
    end
  end

  private

  def account_params
    params.require(:account).permit(:name, :description, :email)
  end
end
```

Approval workflows are best started just before data is about to be created,
updated, or destroyed. Approval workflows are not intended to control permission
to view resources. The actions we recommend guarding are `create`, `update`, and
`destroy` based on your needs.

### Audit trails

#### Publishing events to Cased

Once Cased is setup there are two ways to publish your first audit trail event.
The first is using the `cased` helper method included in all ActiveRecord models.
Using the `cased` helper method will automatically include the current model's
machine representation and string representation in all audit events published
from within the model. In this case the Team model would have a `team` field.

```ruby
class Team < ApplicationRecord
  def add_member(user)
    cased :add_member, user: user
  end
end
```

The second way to publish events to Cased is manually using the `Cased.publish` method:

```ruby
Cased.publish(
  action: 'team.add_member',
  user: user,
  team: team,
)
```

Both examples above are equivalent in that they publish the following `credit_card.charge` audit event to Cased:

```json
{
  "action": "team.add_member",
  "user": "user@cased.com",
  "user_id": "User;2",
  "team": "Employees",
  "team_id": "Team;1",
  "timestamp": "2020-06-23T02:02:39.932759Z"
}
```

It's important when considering where to publish audit trail events in your application you publish them in places you can guarantee information has actually changed. You should also take into account that every model may be created across many places in your application. Only publish audit trail events when you can guarantee something has been created, updated, or deleted.

For those reasons, we highly recommend using `after_commit` callbacks whenever possible:

```ruby
class User < ApplicationRecord
  after_commit :publish_user_create_to_cased, on: :create

  private

  def publish_user_create_to_cased
    cased :create
  end
end
```

If you use any other callback method in the ActiveRecord lifecycle other than `*_commit` you risk publishing an audit event when it does not pass validation or persist to your database.

Take the example of publishing an audit event for creating a new team in a controller:

```ruby
class TeamsController < ApplicationController
  def create
    team = current_organization.teams.new(team_params)
    if team.save
      team.cased(:create)
      # ...
    else
      # ...
    end
  end
end
```

By publishing the `team.create` audit event within the controller directly as shown you risk not having a complete and comprehensive audit trail for each team created in your application as it may happen in your API, model callbacks, and more.

#### Publishing audit events for all record creation, updates, and deletions automatically

Cased provides a mixin you can include in your models or in `ApplicationRecord` to automatically publish when new models are created, updated, or destroyed.

```ruby
class User < ApplicationRecord
  include Cased::Model::Automatic
end
```

Or for all models in your codebase:

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include Cased::Model::Automatic
end
```

This mixin is intended to get you up and running quickly. You'll likely need to configure your own callbacks to control what exactly gets published to Cased.

#### Retrieving events from a Cased audit trail

If you plan on retrieving events from your audit trails to power a user facing audit trail or API you must use a Cased API key.

```ruby
Cased.configure do |config|
  config.policy_key = 'policy_live_1dQpY5JliYgHSkEntAbMVzuOROh'
end

class AuditTrailController < ApplicationController
  def index
    query = Cased.policy.events(phrase: params[:query])
    results = query.page(params[:page]).limit(params[:limit])

    respond_to do |format|
      format.json do
        render json: results
      end

      format.xml do
        render xml: results
      end
    end
  end
end
```

#### Retrieving events from multiple Cased audit trails

To retrieve events from one or more Cased audit trails you can configure multiple Cased API keys and retrieve events for each one by fetching their respective clients.

```ruby
Cased.configure do |config|
  config.policy_keys = {
    users: 'policy_live_1dQpY8bBgEwdpmdpVrrtDzMX4fH',
    organizations: 'policy_live_1dSHQRurWX8JMYMbkRdfzVoo62d',
  }
end

query = Cased.policies[:users].events.limit(25).page(1)
results = query.results
results.each do |event|
  puts event['action'] # => user.login
  puts event['timestamp'] # => 2020-06-23T02:02:39.932759Z
end

query = Cased.policies[:organizations].events.limit(25).page(1)
results = query.results
results.each do |event|
  puts event['action'] # => organization.create
  puts event['timestamp'] # => 2020-06-22T22:16:31.055655Z
end
```

#### Exporting events

Exporting events from Cased allows you to provide users with exports of their own data or to respond to data requests.

```ruby
Cased.configure do |config|
  config.policy_key = 'policy_live_1dQpY5JliYgHSkEntAbMVzuOROh'
end

export = Cased.policy.exports.create(
  format: :json,
  phrase: 'action:credit_card.charge',
)
export.download_url # => https://api.cased.com/exports/export_1dSHQSNtAH90KA8zGTooMnmMdiD/download?token=eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidXNlcl8xZFFwWThiQmdFd2RwbWRwVnJydER6TVg0ZkgiLCJ
```

#### Masking & filtering sensitive information

If you are handling sensitive information on behalf of your users you should consider masking or filtering any sensitive information.

```ruby
Cased.configure do |config|
  config.publish_key = 'publish_live_1dQpY1jKB48kBd3418PjAotmEwA'
end

Cased.publish(
  action: 'credit_card.charge',
  user: Cased::Sensitive::String.new('user@domain.com', label: :email),
)
```

#### Console Usage

Most Cased events will be created by users from actions on the website from
custom defined events or lifecycle callbacks. The exception is any console
session where models may generate Cased events as you start to modify records.

By default any console session will include the hostname of where the console
session takes place. Since every event must have an actor, you must set the
actor at the beginning of your console session. If you don't know the user,
it's recommended you create a system/robot user.

```ruby
Rails.application.console do
  Cased.context.merge(actor: User.find_by!(login: ENV['USER']))
end
```

#### Disable publishing events

Although rare, there may be times where you wish to disable publishing events to Cased. To do so wrap your transaction inside of a `Cased.disable` block:

```ruby
Cased.disable do
  user.cased(:login)
end
```

Or you can configure the entire process to disable publishing events.

```
CASED_DISABLE_PUBLISHING=1 bundle exec ruby crawl.rb
```

#### Context

When you include `cased-rails` in your application your Ruby on Rails application is configures a [Rack middleware](https://github.com/cased/cased-ruby/blob/master/lib/cased/rack_middleware.rb) that populates `Cased.context` with the following information for each request:

- Request IP address
- User agent
- Request ID
- Request URL
- Request HTTP method

To customize the information included in all events that occur through your controllers you can do so by returning a hash in the `cased_initial_request_context` method:

```ruby
class ApplicationController < ActionController::Base
  def cased_initial_request_context
    {
      location: request.remote_ip,
      request_http_method: request.method,
      request_user_agent: request.headers['User-Agent'],
      request_url: request.original_url,
      request_id: request.request_id,
    }
  end
end
```

Any information stored in `Cased.context` will be included for all audit events published to Cased.

```ruby
Cased.context.merge(location: 'hostname.local')

Cased.publish(
  action: 'console.start',
  user: 'john',
)
```

Results in:

```json
{
  "cased_id": "5f8559cd-4cd9-48c3-b1d0-6eedc4019ec1",
  "action": "user.login",
  "user": "john",
  "location": "hostname.local",
  "timestamp": "2020-06-22T21:43:06.157336"
}
```

You can provide a block to `Cased.context.merge` and the provided context will only be present for the duration of the block:

```ruby
Cased.context.merge(location: 'hostname.local') do
  # Will include { "location": "hostname.local" }
  Cased.publish(
    action: 'console.start',
    user: 'john',
  )
end

# Will not include { "location": "hostname.local" }
Cased.publish(
  action: 'console.end',
  user: 'john',
)
```

To clear/reset the context:

```ruby
Cased.context.clear
```

#### Testing

`cased-rails` provides a Cased::TestHelper test helper class that you can use to test events are being published to Cased.

```ruby
require 'test-helper'

class CreditCardTest < Test::Unit::TestCase
  include Cased::TestHelper

  def test_charging_credit_card_publishes_credit_card_create_event
    credit_card = credit_cards(:visa)
    credit_card.charge

    assert_cased_events 1, action: 'credit_card.charge', amount: 2000
  end

  def test_charging_credit_card_publishes_credit_card_create_event_with_block
    credit_card = credit_cards(:visa)

    assert_cased_events 1, action: 'credit_card.charge', amount: 2000 do
      credit_card.charge
    end
  end

  def test_charging_credit_card_with_zero_amount_does_not_publish_credit_card_create_event
    credit_card = credit_cards(:visa)

    assert_no_cased_events do
      credit_card.charge
    end
  end
end
```

## Customizing cased-rails

Out of the box cased-rails takes care of serializing objects for you to the best of its ability, but you can customize cased-rails should you like to fit your products needs.

Let's look at each of these methods independently as they all work together to
create the event.

`Cased::Model#cased`

This method is what publishes events for you to Cased. You include information specific to a particular event when calling `Cased::Model#cased`:

```ruby
class CreditCard < ApplicationRecord
  def charge
    Stripe::Charge.create(
      amount: amount,
      currency: currency,
      source: source,
      description: description,
    )

    cased(:charge, payload: {
      amount: amount,
      currency: currency,
      description: description,
    })
  end
end
```

Or you can customize information that is included anytime `Cased::Model#cased` is called in your class:

```ruby
class CreditCard < ApplicationRecord
  def charge
    Stripe::Charge.create(
      amount: amount,
      currency: currency,
      source: source,
      description: description,
    )

    cased(:charge)
  end

  def cased_payload
    {
      credit_card: self,
      amount: amount,
      currency: currency,
      description: description,
    }
  end
end
```

Both examples are equivelent.

`Cased::Model#cased_category`

By default `cased_category` will use the underscore class name to generate the
prefix for all events generated by this class. If you published a
`CreditCard#charge` event it would be delivered to Cased `credit_card.charge`. If you want to
customize what cased-rails uses you can do so by re-opening the method:

```ruby
class CreditCard < ApplicationRecord
  def cased_category
    :card
  end
end
```

`Cased::Model#cased_id`

Per our guide on [Human and machine readable information](https://docs.cased.com/guides/design-audit-trail-events#human-and-machine-readable-information) for [Designing audit trail events](https://docs.cased.com/guides/design-audit-trail-events) we encourage you to publish a unique identifier that will never change to Cased along with your events. This way when you [retrieve events](#retrieving-events-from-a-cased-audit-trail) from Cased you'll be able to locate the corresponding object in your system.

```ruby
class User < ApplicationRecord
  def cased_id
    database_id
  end
end
```

`Cased::Model#cased_context`

To assist you in publishing events to Cased that are consistent and predictable, cased-rails attempts to build your `cased_context` as long as you implement either `to_s` or `cased_id` in your class:

```ruby
class Plan < ApplicationRecord
  def to_s
    name
  end
end

plan = Plan.new(name: 'Free')
plan.name # => 'Free'
plan.to_s # => 'Free'
plan.id # => 1
plan.cased_id # => Plan;1
plan.cased_context # => { plan: 'Free', plan_id: 'Plan;1' }
```

If your class does not implement `to_s` it will only include `cased_id`:

```ruby
class Plan < ApplicationRecord
end

plan = Plan.new(name: 'Free')
plan.to_s # => '#<Plan:0x00007feadf63b7e0>'
plan.cased_context # => { plan_id: 'Plan;1' }
```

Or you can customize it if your `to_s` implementation is not suitable for Cased:

```ruby
class Plan < ApplicationRecord
  has_many :credit_cards

  def to_s
    name
  end

  def cased_context(category: cased_category)
    {
      "#{category}_id".to_sym => cased_id,
      category => @name.parameterize,
    }
  end
end

class CreditCard < ApplicationRecord
  belongs_to :plan

  def charge
    Stripe::Charge.create(
      amount: amount,
      currency: currency,
      source: source,
      description: description,
    )

    cased(:charge, payload: {
      amount: amount,
      currency: currency,
      description: description,
    })
  end

  def cased_payload
    {
      credit_card: self,
      plan: plan,
    }
  end
end

credit_card = CreditCard.new(
  amount: 2000,
  currency: 'usd',
  source: 'tok_amex',
  description: 'My First Test Charge (created for API docs)',
)

credit_card.charge
```

Results in:

```json
{
  "cased_id": "5f8559cd-4cd9-48c3-b1d0-6eedc4019ec1",
  "action": "credit_card.charge",
  "credit_card": "personal",
  "credit_card_id": "card_1dQpXqQwXxsQs9sohN9HrzRAV6y",
  "plan": "Free",
  "plan_id": "plan_1dQpY1jKB48kBd3418PjAotmEwA",
  "timestamp": "2020-06-22T20:24:04.815758"
}
```

## Contributing

1. Fork it ( https://github.com/cased/cased-rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
# cannon
