Manual WAF deployment and configuration can be a tedious process, causing long lead times and changes are often vulnerable to misconfiguration errors, potentially affecting the availability of live services. This SPIKE identifies how terraform could be used to automate WAF deployment and their configuration, outlining common WAF providers and their support levels with terraform.

Web Application Firewall (WAF) is a firewall and reverse proxy which helps protect against web application attacks by filtering and monitoring HTTP traffic between a web application and the internet. A WAF continuously inspects inbound and outbound requests against a set of rules or policies, which aim to filter out and protect against common application exploits such as cross-site forgery, cross-site-scripting, file inclusion and SQL injection, among others.

Terraform is a software tool that uses a declarative and stateful approach to deploy and manage infrastructure and supporting components. By making use of terraform modules and DRY principals you can efficiently manage WAF configuration and introduce automation to manage different components, reducing an element of human error and providing a consistent and transparent approach to configuration management. 
 
Terraform is a cloud agnostic tool, allowing the provisioning of resources across different cloud vendors and doesn’t lock a client into any specific cloud, which also applies to WAF vendors. Enabling flexibility between WAF vendors allows teams to choose a provider based on their use case, whether that's cost, security or exclusive features. As these priorities change over time, terraform allows a smoother transition between WAF vendors by keeping the same standardisation approach to the provisioning and configuration of a WAF, only changing the specific terraform resources which vary per WAF vendor. 
 
Terraform uses a concept called terraform providers which are used to integrate with any upstream API and is a library of resources which are published and maintained by different sources. Tiers and badges are used to share the level of support and ownership of a provider. Below describes the different tiers:

Official: Official providers are owned and maintained by HashiCorp, these include providers such as hashicorp/aws, hashicorp/azurerm and hashicorp/google

Partner: Partner providers are written and maintained by third-party companies against their own API. To earn this status, the partner must participate in the HashiCorp Technology Partner Program. An example of this would be fastly/fastly

Community - Community providers could be published by individual maintainers or other members of the terraform community to integrate with an upstream API. This can also include organisations which do not participate in the HashiCorp Technology Partner Program. An example of this is imperva/Incapsula

Archived - Archived providers are no longer maintained by Hashicorp or the community, this may occur if an API is deprecated, or interest was low.

There are plenty of WAF vendors to choose from and below outlines the most common ones I found and their provider support levels:

Official:
•	Microsoft Azure App Gateway - https://registry.terraform.io/providers/hashicorp/azurerm/latest
•	AWS WAF - https://registry.terraform.io/providers/hashicorp/aws/latest
•	GCP Cloud Armor - https://registry.terraform.io/providers/hashicorp/google/latest
 
Partner:
•	Barracuda WAF - https://registry.terraform.io/providers/barracudanetworks/barracudawaf/latest
•	Akamai - https://registry.terraform.io/providers/akamai/akamai/latest
•	Cloudflare - https://registry.terraform.io/providers/cloudflare/cloudflare/latest
•	F5 Big Ip - https://registry.terraform.io/providers/F5Networks/bigip/latest
•	Fastly - https://registry.terraform.io/providers/fastly/fastly/latest
 
Community:
•	Imperva WAF - https://registry.terraform.io/providers/imperva/incapsula/latest
•	Wallarm WAF - https://registry.terraform.io/providers/wallarm/wallarm/latest
 
None:
•	Fortinet FortiWeb. There are various fortinet terraform providers, however for their WAF service it looks like they have a manual terraform provider that you need to download via github. Instructions on how to use can be found through their official documentation here: https://docs.fortinet.com/document/fortiweb-cloud/latest/user-guide/324748/configuring-fortiweb-cloud-with-terraform 
•	Radware – I couldn’t find anything actively maintained.

