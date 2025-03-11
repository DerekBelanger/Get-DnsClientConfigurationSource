function Get-DnsClientConfigurationSource {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $NetAdapter, # This varaible is used whenever there is a single NetAdapter object, so dont think of it as an immutable input object

        [ValidateNotNullOrEmpty()]
        [int]$InterfaceIndex,

        [ValidateNotNullOrEmpty()]
        [string]$InterfaceAlias
    )
    
    begin {
        $DnsClientServerAddresses =@() # Collection returned by function
        $NetAdapters =@()
        
        if ($InterfaceIndex) {$NetAdapter = Get-NetAdapter -InterfaceIndex $InterfaceIndex}
        elseif ($InterfaceAlias) {$NetAdapter = Get-NetAdapter -InterfaceAlias $InterfaceAlias}
        elseif (-not $PSCmdlet.MyInvocation.ExpectingInput) {$NetAdapters = Get-NetAdapter}
    }
    
    process {
        if ($NetAdapter) {$NetAdapters += $NetAdapter}
    }
    
    end {
        foreach ($NetAdapter in $NetAdapters) {
            
            $NetAdapter | Get-DnsClientServerAddress | ForEach-Object {
                
                switch ($_.AddressFamily) {
                    2 {$IPRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($NetAdapter.InterfaceGuid)"}
                    23 {$IPRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$($NetAdapter.InterfaceGuid)"}
                }
    
                $InterfaceProperties = Get-ItemProperty -Path $IPRegPath         
                
                if ($InterfaceProperties.EnableDHCP -ne 1) {$ConfigurationSource = "Static"}
                elseif ($InterfaceProperties.NameServer) {$ConfigurationSource = "Static"}
                else {$ConfigurationSource = "DHCP"}

                $_ | Add-Member -NotePropertyName "ConfigurationSource" -NotePropertyValue "$ConfigurationSource"    
                $DnsClientServerAddresses += $_
            }
        }    
        # Because Get-DnsClientServerAddress uses calculated property for AddressFamily, we have to do the same
        $AddressFamilyDisplay = @{
            Name = "AddressFamily"
            Expression = { 
                if ($_.AddressFamily -eq 2) {"IPv4"} 
                elseif ($_.AddressFamily -eq 23) {"IPv6"}
            }
        }
        $DnsClientServerAddresses | Format-Table InterfaceAlias, InterfaceIndex, $AddressFamilyDisplay, ServerAddresses, ConfigurationSource    
    }
}