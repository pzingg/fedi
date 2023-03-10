defmodule FediServerWeb.StatusComponent do
  @moduledoc false

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  def status(assigns) do
    ~H"""
    <article data-domain={@act.domain} data-id={@act.id}>
      <div tabindex="-1">
        <div class="status__wrapper status__wrapper-public focusable" tabindex="0" aria-label={@act.aria_label}>
          <%= if @act.boost_id do %>
          <div class="status__prepend">
            <div class="status__prepend-icon-wrapper">
              <i role="img" class="fa fa-retweet status__prepend-icon fa-fw"></i>
            </div>
            <span>
              <a data-id={@act.boost_id} href={@act.booster_url} class="status__display-name muted">
                <strong><%= @act.booster_name %></strong>
              </a> boosted
            </span>
          </div>
          <% end %>
          <div class="status status-public">
            <div class="status__expand" role="presentation"></div>
            <div class="status__info">
              <a href={@act.object_id} class="status__relative-time" target="_blank" rel="noopener noreferrer">
                <span class="status__visibility-icon">
                  <i role="img" class="fa fa-globe" title="Public"></i>
                </span>
                <time datetime={@act.published_utc} title={@act.published_title}><%= @act.published_relative %></time>
              </a>
              <a href={@act.attributed_to_url} title={@act.attributed_to_account} class="status__display-name" target="_blank" rel="noopener noreferrer">
                <div class="status__avatar">
                  <div class="account__avatar">
                    <img src={@act.attributed_to_avatar_url} />
                  </div>
                </div>
                <span class="display-name">
                  <strong class="display-name__html"><%= @act.attributed_to_name %></strong>
                  <span class="display-name__account"><%= @act.attributed_to_account %></span>
                </span>
              </a>
            </div>
            <div class="status__content status__content--with-action" tabindex="0">
              <div class="status__content__text status__content__text--visible translate">
                <%= raw @act.content_html %>
              </div>
            </div>
            <div class="status__action-bar">
              <button aria-label="Reply" title="Reply" class="status__action-bar-button icon-button icon-button--with-counter" tabindex="0" style="font-size: 18px; width: auto; height: 23.1429px; line-height: 18px;">
                <i role="img" class="fa fa-reply fa-fw" aria-hidden="true"></i>
                <span class="icon-button__counter">
                  <span class="animated-number">
                    <span style="position: static; transform: translateY(0%);"><%= @act.reply_count %></span>
                  </span>
                </span>
              </button>
              <button aria-label="Boost" aria-pressed="false" title="Boost" class="status__action-bar-button icon-button" tabindex="0" style="font-size: 18px; width: 23.1429px; height: 23.1429px; line-height: 18px;">
                <i role="img" class="fa fa-retweet fa-fw" aria-hidden="true"></i>
              </button>
              <button aria-label="Favourite" aria-pressed="false" title="Favourite" class="status__action-bar-button star-icon icon-button" tabindex="0" style="font-size: 18px; width: 23.1429px; height: 23.1429px; line-height: 18px;">
                <i role="img" class="fa fa-star fa-fw" aria-hidden="true"></i>
              </button>
              <div class="status__action-bar-dropdown">
                <div>
                  <button aria-label="More" title="More" class="icon-button" tabindex="0" style="font-size: 18px; width: 23.1429px; height: 23.1429px; line-height: 18px;">
                    <i role="img" class="fa fa-ellipsis-h fa-fw" aria-hidden="true"></i>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end
end
